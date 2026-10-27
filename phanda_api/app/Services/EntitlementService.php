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
 * Nothing is cached: an expiry or a webhook activation must take effect on the
 * very next request.
 */
final class EntitlementService
{
    public function tierFor(User $user): AccessTier
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
        return DocumentPurchase::query()
            ->where('user_id', $user->id)
            ->where('status', 'paid')
            ->where(function ($query): void {
                $query->whereNull('expires_at')->orWhere('expires_at', '>', now());
            })
            ->pluck('document_id')
            ->all();
    }

    public function forget(User $user): void
    {
        // Kept for callers that used the cached implementation; entitlement is
        // now evaluated per request.
    }
}
