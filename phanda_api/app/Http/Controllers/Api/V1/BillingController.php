<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Contracts\PaymentGateway;
use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\CheckoutRequest;
use App\Http\Resources\PlanResource;
use App\Models\Document;
use App\Models\DocumentPurchase;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\User;
use App\Services\BillingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use RuntimeException;
use Throwable;

final class BillingController extends ApiController
{
    public function __construct(
        private readonly BillingService $billing,
        private readonly PaymentGateway $gateway,
    ) {}

    public function plans(): JsonResponse
    {
        return $this->success(
            PlanResource::collection(
                Plan::query()->where('is_active', true)->orderBy('sort_order')->get()
            )
        );
    }

    public function status(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return $this->success($this->billing->statusFor($user));
    }

    public function checkout(CheckoutRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        try {
            if ($request->filled('plan_id')) {
                $plan = Plan::query()->where('is_active', true)->findOrFail((int) $request->input('plan_id'));
                $result = $this->billing->checkoutPlan($user, $plan);
            } else {
                $document = Document::query()->findOrFail((string) $request->input('document_id'));
                $result = $this->billing->checkoutDocument($user, $document);
            }
        } catch (RuntimeException $exception) {
            return $this->error($exception->getMessage(), $exception->getCode() ?: 400);
        } catch (Throwable $exception) {
            report($exception);

            return $this->error('The checkout could not be started. Try again.', 500);
        }

        return $this->created($result, 'Checkout created. Complete the payment with PayChangu.');
    }

    public function payment(Request $request, string $txRef): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        try {
            return $this->success($this->billing->refreshPayment($user, $txRef), 'Payment status');
        } catch (RuntimeException $exception) {
            return $this->error($exception->getMessage(), $exception->getCode() ?: 400);
        }
    }

    /**
     * Browser return URL. PayChangu redirects here after checkout; the app polls
     * /billing/payments/{tx_ref} and does not depend on this page.
     */
    public function callback(string $txRef): Response
    {
        $subscription = Subscription::query()->where('tx_ref', $txRef)->first();
        $purchase = DocumentPurchase::query()->where('tx_ref', $txRef)->first();

        if ($subscription !== null) {
            $this->billing->refreshPayment($subscription->user, $txRef);
        } elseif ($purchase !== null) {
            $this->billing->refreshPayment($purchase->user, $txRef);
        }

        return response(
            '<!doctype html><html><body style="font-family:sans-serif;padding:2rem">'
            .'<h1>Payment received</h1><p>You can close this page and return to Kuphanda.</p>'
            .'</body></html>',
            200,
            ['Content-Type' => 'text/html; charset=utf-8']
        );
    }

    /**
     * PayChangu webhook. The signature is checked first, then the transaction
     * is verified with the provider before entitlement is granted.
     */
    public function webhook(Request $request): JsonResponse
    {
        $payload = $request->getContent();
        $signature = (string) $request->header('Signature', '');

        if (! $this->gateway->verifyWebhookSignature($payload, $signature)) {
            return $this->error('Invalid signature', 401);
        }

        $data = json_decode($payload, true);

        if (! is_array($data)) {
            return $this->error('Invalid payload', 400);
        }

        $txRef = $data['tx_ref'] ?? $data['data']['tx_ref'] ?? null;

        if (! is_string($txRef) || $txRef === '') {
            return $this->error('Missing transaction reference', 422);
        }

        if (! $this->billing->activateFromWebhook($txRef)) {
            return $this->error('Payment could not be verified', 409);
        }

        return $this->success(message: 'Payment processed');
    }
}
