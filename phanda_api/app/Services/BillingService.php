<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\PaymentGateway;
use App\Enums\AccessTier;
use App\Enums\SubscriptionStatus;
use App\Models\Document;
use App\Models\DocumentPurchase;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Creates payable records, asks PayChangu for a checkout URL, verifies the
 * transaction with the provider, and only then grants entitlement. The webhook
 * and the client's status poll both call the same activation path, so a payment
 * can never be granted twice.
 */
final class BillingService
{
    public function __construct(
        private readonly PaymentGateway $gateway,
        private readonly EntitlementService $entitlements,
    ) {}

    /**
     * @return array{tx_ref: string, checkout_url: string, amount_mwk: int, kind: string}
     */
    public function checkoutPlan(User $user, Plan $plan): array
    {
        if (! $plan->is_active) {
            throw new RuntimeException('That plan is not on sale.', 422);
        }

        $active = Subscription::query()
            ->where('user_id', $user->id)
            ->where('status', SubscriptionStatus::Active)
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>', now());
            })
            ->exists();

        if ($active) {
            throw new RuntimeException('You already have an active subscription.', 409);
        }

        $txRef = 'SUB-'.Str::uuid();
        $subscription = Subscription::query()->create([
            'user_id' => $user->id,
            'plan_id' => $plan->id,
            'status' => SubscriptionStatus::Pending,
            'tx_ref' => $txRef,
            'amount_mwk' => $plan->price_mwk,
        ]);

        return $this->initiate($user, $txRef, $plan->price_mwk, [
            'title' => $plan->name.' subscription',
            'description' => 'Kuphanda library access for '.$plan->duration_days.' days',
            'meta' => [
                'kind' => 'subscription',
                'subscription_id' => $subscription->id,
                'plan_id' => $plan->id,
            ],
        ], 'subscription');
    }

    /**
     * @return array{tx_ref: string, checkout_url: string, amount_mwk: int, kind: string}
     */
    public function checkoutDocument(User $user, Document $document): array
    {
        if (! $document->is_published) {
            throw new RuntimeException('That document is not available.', 404);
        }

        if ($this->entitlements->canAccess($user, $document)) {
            throw new RuntimeException('You already have access to this document.', 409);
        }

        if ($document->price_mwk <= 0) {
            throw new RuntimeException('This document needs a subscription, not a single purchase.', 422);
        }

        $txRef = 'DOC-'.Str::uuid();
        $purchase = DocumentPurchase::query()->create([
            'user_id' => $user->id,
            'document_id' => $document->id,
            'status' => 'pending',
            'tx_ref' => $txRef,
            'amount_mwk' => $document->price_mwk,
        ]);

        return $this->initiate($user, $txRef, $document->price_mwk, [
            'title' => $document->title,
            'description' => 'Single-document access',
            'meta' => [
                'kind' => 'document',
                'purchase_id' => $purchase->id,
                'document_id' => $document->id,
            ],
        ], 'document');
    }

    /**
     * Polling endpoint: verifies with PayChangu, activates on success, and
     * reports the resulting entitlement in the same response.
     *
     * @return array<string, mixed>
     */
    public function refreshPayment(User $user, string $txRef): array
    {
        $subscription = Subscription::query()
            ->where('user_id', $user->id)
            ->where('tx_ref', $txRef)
            ->with('plan')
            ->first();

        $purchase = $subscription === null
            ? DocumentPurchase::query()
                ->where('user_id', $user->id)
                ->where('tx_ref', $txRef)
                ->first()
            : null;

        if ($subscription === null && $purchase === null) {
            throw new RuntimeException('Payment not found.', 404);
        }

        if ($subscription?->status === SubscriptionStatus::Active || $purchase?->status === 'paid') {
            return $this->statusPayload($user, $txRef);
        }

        $verification = $this->gateway->verifyTransaction($txRef);

        if ($verification['verified']) {
            $expected = $subscription?->amount_mwk ?? $purchase?->amount_mwk ?? 0;
            $paidAmount = (float) ($verification['amount'] ?? 0);

            if ($paidAmount + 0.01 < $expected) {
                throw new RuntimeException('The amount received does not match the price.', 409);
            }

            $this->activate($txRef, $verification['data'] ?? []);
            $this->entitlements->forget($user);
        }

        return $this->statusPayload($user, $txRef);
    }

    /**
     * Called by the signed webhook. The provider's payload is not trusted on
     * its own: the transaction is re-verified before access is granted.
     */
    public function activateFromWebhook(string $txRef): bool
    {
        $verification = $this->gateway->verifyTransaction($txRef);

        if (! $verification['verified']) {
            return false;
        }

        return $this->activate($txRef, $verification['data'] ?? []);
    }

    /**
     * @param  array<string, mixed>  $providerData
     */
    public function activate(string $txRef, array $providerData = []): bool
    {
        $subscription = Subscription::query()->where('tx_ref', $txRef)->with('plan')->first();

        if ($subscription !== null) {
            if ($subscription->status === SubscriptionStatus::Active) {
                return true;
            }

            $start = Carbon::now();
            $subscription->update([
                'status' => SubscriptionStatus::Active,
                'starts_at' => $start,
                'ends_at' => $start->copy()->addDays($subscription->plan->duration_days),
                'paid_at' => $start,
                'provider_data' => $providerData,
            ]);

            $this->entitlements->forget($subscription->user);

            return true;
        }

        $purchase = DocumentPurchase::query()->where('tx_ref', $txRef)->first();

        if ($purchase !== null) {
            if ($purchase->status === 'paid') {
                return true;
            }

            $purchase->update([
                'status' => 'paid',
                'purchased_at' => Carbon::now(),
                'provider_data' => $providerData,
            ]);

            if ($purchase->user !== null) {
                $this->entitlements->forget($purchase->user);
            }

            return true;
        }

        return false;
    }

    /**
     * @return array<string, mixed>
     */
    public function statusFor(User $user): array
    {
        $subscription = Subscription::query()
            ->where('user_id', $user->id)
            ->where('status', SubscriptionStatus::Active)
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>', now());
            })
            ->with('plan')
            ->orderByDesc('ends_at')
            ->first();

        return [
            'tier' => $this->entitlements->tierFor($user)->value,
            'plan' => $user->plan->value,
            'subscription' => $subscription === null ? null : [
                'tx_ref' => $subscription->tx_ref,
                'plan' => $subscription->plan->name,
                'tier' => $subscription->plan->access_tier->value,
                'ends_at' => $subscription->ends_at?->toIso8601String(),
                'status' => $subscription->status->value,
            ],
            'purchases' => $this->entitlements->purchasedDocumentIds($user),
            'currency' => config('services.paychangu.currency', 'MWK'),
        ];
    }

    /**
     * @param  array<string, mixed>  $customisation
     * @return array{tx_ref: string, checkout_url: string, amount_mwk: int, kind: string}
     */
    private function initiate(User $user, string $txRef, int $amount, array $customisation, string $kind): array
    {
        $parts = preg_split('/\s+/', trim($user->name)) ?: [$user->name];

        $response = $this->gateway->initiatePayment([
            'amount' => $amount,
            'currency' => config('services.paychangu.currency', 'MWK'),
            'email' => $user->email,
            'first_name' => $parts[0] ?? '',
            'last_name' => $parts[1] ?? '',
            'callback_url' => route('api.v1.billing.callback', ['txRef' => $txRef]),
            'return_url' => route('api.v1.billing.callback', ['txRef' => $txRef]),
            'tx_ref' => $txRef,
            'title' => $customisation['title'] ?? 'Kuphanda',
            'description' => $customisation['description'] ?? 'Library access',
            'meta' => $customisation['meta'] ?? [],
        ]);

        if (! ($response['success'] ?? false) || empty($response['checkout_url'])) {
            Subscription::query()->where('tx_ref', $txRef)->delete();
            DocumentPurchase::query()->where('tx_ref', $txRef)->delete();

            throw new RuntimeException(
                $response['message'] ?? 'The payment provider did not return a checkout page.',
                502
            );
        }

        return [
            'tx_ref' => $txRef,
            'checkout_url' => (string) $response['checkout_url'],
            'amount_mwk' => $amount,
            'kind' => $kind,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function statusPayload(User $user, string $txRef): array
    {
        $subscription = Subscription::query()->where('tx_ref', $txRef)->with('plan')->first();
        $purchase = DocumentPurchase::query()->where('tx_ref', $txRef)->first();

        $status = $subscription?->status->value ?? $purchase?->status ?? 'unknown';

        return [
            'tx_ref' => $txRef,
            'status' => $status === 'paid' ? 'paid' : $status,
            'kind' => $subscription !== null ? 'subscription' : 'document',
            'entitlement' => $this->statusFor($user),
        ];
    }
}
