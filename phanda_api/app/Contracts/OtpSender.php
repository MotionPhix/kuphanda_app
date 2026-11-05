<?php

declare(strict_types=1);

namespace App\Contracts;

/**
 * Delivers a one-time sign-in code to a phone.
 *
 * Only WhatsApp is implemented. The interface exists so the transport can be
 * swapped without touching the sign-in flow — a business provider (Mithenga,
 * Twilio, Infobip) differs from the Cloud API only in this class.
 *
 * A send failure must be reported, not swallowed: unlike a notification, a code
 * that never arrives leaves the person staring at a box they cannot fill.
 */
interface OtpSender
{
    /** @param  string  $e164  The number as stored, with the leading plus. */
    public function sendCode(string $e164, string $code): bool;

    /** Whether real credentials are configured. */
    public function isConfigured(): bool;

    /** Human-readable transport name, for the health endpoint. */
    public function transport(): string;
}
