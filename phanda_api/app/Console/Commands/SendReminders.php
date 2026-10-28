<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\SubscriptionStatus;
use App\Models\Subscription;
use App\Services\Push\PushDispatcher;
use Illuminate\Console\Command;

/**
 * Daily reminder sweep. Today it covers subscription expiry, which is the part
 * of the product the server owns; study and exam reminders are derived from the
 * learner's own device data.
 */
final class SendReminders extends Command
{
    protected $signature = 'notifications:reminders {--days=3 : Remind this many days before expiry}';

    protected $description = 'Push subscription expiry reminders to learners';

    public function handle(PushDispatcher $push): int
    {
        $days = max(1, (int) $this->option('days'));
        $cutoff = now()->addDays($days);

        $subscriptions = Subscription::query()
            ->where('status', SubscriptionStatus::Active)
            ->whereNotNull('ends_at')
            ->where('ends_at', '>', now())
            ->where('ends_at', '<=', $cutoff)
            ->where(function ($query): void {
                $query->whereNull('expiry_reminded_at')
                    ->orWhere('expiry_reminded_at', '<', now()->subDay());
            })
            ->with(['user', 'plan'])
            ->get();

        $sent = 0;

        foreach ($subscriptions as $subscription) {
            $daysLeft = max(0, (int) ceil(now()->diffInDays($subscription->ends_at, false)));

            try {
                $push->subscriptionExpiring($subscription, $daysLeft);
            } catch (\Throwable $error) {
                report($error);

                continue;
            }

            // Recorded even when no device is registered, so the sweep does not
            // retry the same learner every night.
            $subscription->forceFill(['expiry_reminded_at' => now()])->save();
            $sent++;
        }

        $this->info("Sent {$sent} expiry reminder(s).");

        return self::SUCCESS;
    }
}
