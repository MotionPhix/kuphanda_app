<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\User;

/**
 * Sends the "verify your email" link.
 *
 * Wrapped in its own class so the sign-up path can treat a dead mail server as
 * a nuisance rather than a failure. On shared hosting SMTP is the least
 * reliable thing in the stack, and a learner should not lose the account they
 * just created because the mail host was unreachable.
 */
class VerificationMailer
{
    public function send(User $user): void
    {
        $user->sendEmailVerificationNotification();
    }
}

