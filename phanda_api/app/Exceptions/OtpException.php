<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;

/**
 * A refused code, with a reason the app can branch on and a sentence a learner
 * can read.
 *
 * Deliberately distinct from "wrong code": expired, already used, and out of
 * attempts need different words on screen and different behaviour in the sheet
 * (offer a new code, or stop offering one for a while).
 */
final class OtpException extends RuntimeException
{
    private function __construct(
        public readonly string $reason,
        string $message,
        private readonly int $status,
    ) {
        parent::__construct($message);
    }

    public static function invalid(): self
    {
        return new self('OTP_INVALID', 'That code is not right. Check the six digits and try again.', 422);
    }

    public static function expired(): self
    {
        return new self('OTP_EXPIRED', 'That code has expired. Ask for a new one.', 422);
    }

    public static function tooManyAttempts(): self
    {
        return new self('OTP_ATTEMPTS_EXCEEDED', 'Too many wrong codes. Ask for a new code.', 429);
    }

    public static function resendTooSoon(): self
    {
        return new self('OTP_RESEND_TOO_SOON', 'A code was just sent. Wait a minute before asking again.', 429);
    }

    public static function throttled(): self
    {
        return new self('OTP_THROTTLED', 'Too many codes requested for this number. Try again later.', 429);
    }

    public static function notDelivered(): self
    {
        return new self('OTP_NOT_DELIVERED', 'WhatsApp could not deliver the code. Try again, or sign in with your email.', 503);
    }

    public static function unavailable(): self
    {
        return new self('OTP_CHANNEL_UNAVAILABLE', 'WhatsApp sign-in is not configured on this server yet. Use your email and password.', 503);
    }

    public function status(): int
    {
        return $this->status;
    }
}
