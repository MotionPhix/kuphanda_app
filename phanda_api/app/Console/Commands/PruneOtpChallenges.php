<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\OtpChallenge;
use Illuminate\Console\Command;

/**
 * Deletes sign-in codes once they can no longer matter.
 *
 * The table is a record of who asked to sign in and when; keeping it forever
 * turns a debugging aid into a behavioural log of every learner. A week is long
 * enough to answer "did the code go out?" and short enough to be defensible.
 */
final class PruneOtpChallenges extends Command
{
    protected $signature = 'otp:prune {--days=7 : Keep codes newer than this}';

    protected $description = 'Delete WhatsApp sign-in codes older than the retention window';

    public function handle(): int
    {
        $option = $this->option('days');
        $days = max(1, is_numeric($option) ? (int) $option : 7);
        $cutoff = now()->subDays($days);

        /** @var int $deleted */
        $deleted = OtpChallenge::query()
            ->where('created_at', '<', $cutoff)
            ->delete();

        $this->info('Removed '.$deleted.' code(s) older than '.$days.' day(s).');

        return self::SUCCESS;
    }
}
