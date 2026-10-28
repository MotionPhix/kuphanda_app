<?php

declare(strict_types=1);

namespace App\Services;

use App\Enums\AccessTier;
use App\Enums\LibraryPlan;
use App\Enums\SubscriptionStatus;
use App\Models\Document;
use App\Models\DocumentPurchase;
use App\Models\Subscription;
use App\Models\User;

/**
 * One place decides whether a learner may read a document. Every download,
 * mark and catalogue response uses it, so the UI and the file endpoint can
 * never disagree about entitlement.
 *
 * Results are memoised for the lifetime of one request (the service is a
 * container singleton). A catalogue response would otherwise run two queries
 * per document. Billing invalidates the cache with forget() when it activates
 * a payment, so the very next request — and the rest of the checkout request —
 * sees the new entitlement.
 */
final class EntitlementService
{
    /** @var array<string, AccessTier> */
    private array $tierCache = [];

    /** @var array<string, array<int, string>> */
    private array $purchaseCache = [];

    public function tierFor(User $user): AccessTier
    {
        $key = (string) $user->id;

        return $this->tierCache[$key] ??= $this->computeTier($user);
    }

    private function computeTier(User $user): AccessTier
    {
        $tier = $user->plan === LibraryPlan::School ? AccessTier::School : AccessTier::Free;

        $subscription = Subscription::query()
            ->where('user_id', $user->id)
            ->where('status', SubscriptionStatus::Active)
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>', now());
            })
            ->with('plan')
            ->orderByDesc('ends_at')
            ->first();

        if ($subscription?->plan !== null && $subscription->plan->access_tier->rank() > $tier->rank()) {
            $tier = $subscription->plan->access_tier;
        }

        return $tier;
    }

    public function canAccess(User $user, Document $document): bool
    {
        if (! $document->is_published) {
            return false;
        }

        if ($document->access_tier === AccessTier::Free) {
            return true;
        }

        if ($this->tierFor($user)->rank() >= $document->access_tier->rank()) {
            return true;
        }

        return in_array($document->id, $this->purchasedDocumentIds($user), true);
    }

    /**
     * @return array<int, string>
     */
    public function purchasedDocumentIds(User $user): array
    {
        $key = (string) $user->id;

        if (isset($this->purchaseCache[$key])) {
            return $this->purchaseCache[$key];
        }

        $ids = DocumentPurchase::query()
            ->where('user_id', $user->id)
            ->where('status', 'paid')
            ->where(function ($query): void {
                $query->whereNull('expires_at')->orWhere('expires_at', '>', now());
            })
            ->pluck('document_id')
            ->all();

        return $this->purchaseCache[$key] = $ids;
    }

    /**
     * @param  User|int  $user
     */
    public function forget(User|int $user): void
    {
        $key = (string) ($user instanceof User ? $user->id : $user);
        unset($this->tierCache[$key], $this->purchaseCache[$key]);
    }
}
