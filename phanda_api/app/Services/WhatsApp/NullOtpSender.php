<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

use App\Contracts\OtpSender;

/**
 * What runs when WhatsApp is not configured yet.
 *
 * It refuses rather than pretends. The sign-in endpoint turns this into a 503
 * with a plain explanation, so the app can point at email and Google instead of
 * leaving a learner waiting for a code that was never sent.
 */
final class NullOtpSender implements OtpSender
{
    public function isConfigured(): bool
    {
        return false;
    }

    public function transport(): string
    {
        return 'none';
    }

    public function sendCode(string $e164, string $code): bool
    {
        return false;
    }
}
