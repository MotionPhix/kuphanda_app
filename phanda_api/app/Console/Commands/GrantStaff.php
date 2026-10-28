<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

final class GrantStaff extends Command
{
    protected $signature = 'user:staff
                            {email : Account email}
                            {--revoke : Remove staff access instead}';

    protected $description = 'Grant or revoke library staff access for an account';

    public function handle(): int
    {
        $user = User::query()->where('email', $this->argument('email'))->first();

        if ($user === null) {
            $this->error('No account exists with that email.');

            return self::FAILURE;
        }

        $user->forceFill(['is_staff' => ! $this->option('revoke')])->save();

        $this->info(sprintf(
            '%s staff access for %s.',
            $this->option('revoke') ? 'Revoked' : 'Granted',
            $user->email
        ));

        return self::SUCCESS;
    }
}
