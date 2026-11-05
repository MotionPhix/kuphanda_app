<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Sign-in codes
|--------------------------------------------------------------------------
|
| How long a code lives, how often one number may ask for another, and how many
| wrong guesses retire it. Kept in configuration rather than constants so a
| support call can relax the resend cooldown on a bad network day without a
| code change — but the defaults are the ones that were reasoned about.
|
*/

return [
    // Six digits, ten minutes: long enough for a slow SMS-to-WhatsApp forward,
    // short enough that a code read off a shared screen is stale by the time the
    // next lesson starts.
    'length' => (int) env('OTP_LENGTH', 6),
    'ttl_minutes' => (int) env('OTP_TTL_MINUTES', 10),
    'resend_seconds' => (int) env('OTP_RESEND_SECONDS', 60),
    'hourly_limit' => (int) env('OTP_HOURLY_LIMIT', 5),
    'max_attempts' => (int) env('OTP_MAX_ATTEMPTS', 5),
];
