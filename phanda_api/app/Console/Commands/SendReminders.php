<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Enums\SubscriptionStatus;
use App\Models\ClassroomAssignment;
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

        $reading = $this->remindReadingDueTomorrow($push);

        $this->info("Sent {$sent} expiry reminder(s) and {$reading} reading reminder(s).");

        return self::SUCCESS;
    }

    /**
     * The evening before a paper is due, and again on the day, the learners who
     * have not read it are reminded.
     *
     * Only the ones still to read it: a learner who finished it does not need
     * chasing, and a reminder to the whole class would teach them to ignore it.
     * Keyed on the due date, so a daily sweep produces one message per learner
     * per deadline rather than a stream.
     */
    private function remindReadingDueTomorrow(PushDispatcher $push): int
    {
        $today = now()->toDateString();
        $tomorrow = now()->addDay()->toDateString();

        $assignments = ClassroomAssignment::query()
            ->whereNotNull('due_date')
            ->whereDate('due_date', '>=', $today)
            ->whereDate('due_date', '<=', $tomorrow)
            ->with(['document', 'classroom'])
            ->get();

        $sent = 0;

        foreach ($assignments as $assignment) {
            $classroom = $assignment->classroom;

            if ($classroom === null) {
                continue;
            }

            $done = $assignment->completions()->pluck('user_id')->all();
            $dueToday = $assignment->due_date?->toDateString() === $today;
            $title = $assignment->document?->title ?? 'a paper';

            foreach ($classroom->members()->whereNotIn('users.id', $done)->get() as $member) {
                try {
                    $push->toUser(
                        $member,
                        'reminder',
                        ($dueToday ? 'Due today: ' : 'Due tomorrow: ').$title,
                        $classroom->name,
                        [
                            'classroom_id' => (string) $classroom->id,
                            'assignment_id' => (string) $assignment->id,
                            'document_id' => (string) $assignment->document_id,
                        ],
                    );
                    $sent++;
                } catch (\Throwable $error) {
                    report($error);
                }
            }
        }

        return $sent;
    }
}

