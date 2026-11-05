<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\OtpSender;
use App\Exceptions\OtpException;
use App\Models\OtpChallenge;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

/**
 * Issues and checks the six digits.
 *
 * The rules here are the security of the feature, so they are explicit rather
 * than left to the controller:
 *
 *  - a code is six digits from `random_int`, never `rand`;
 *  - it is stored as a password hash, so the table is not a list of live codes;
 *  - it lives for ten minutes and works once;
 *  - five wrong guesses retire it — 10^6 is brute-forceable in an afternoon
 *    without this, and a phone number is public;
 *  - one send per minute per number, five per hour, so the endpoint cannot be
 *    used to spam someone's WhatsApp at Kuphanda's expense.
 */
final class OtpService
{
    public const PURPOSE_LOGIN = 'login';

    public const PURPOSE_SIGNUP = 'signup';

    public const PURPOSE_LINK = 'link';

    public function __construct(private readonly OtpSender $sender) {}

    public function sender(): OtpSender
    {
        return $this->sender;
    }

    /**
     * Sends a code and returns the challenge it belongs to.
     *
     * @throws OtpException
     */
    public function issue(string $e164, string $purpose, ?User $user = null, ?string $ip = null): OtpChallenge
    {
        if (! $this->sender->isConfigured()) {
            throw OtpException::unavailable();
        }

        $cooldown = $this->number('otp.resend_seconds', 60);
        $hourly = $this->number('otp.hourly_limit', 5);

        $recent = OtpChallenge::query()
            ->where('phone_e164', $e164)
            ->latest('created_at')
            ->first();

        if ($recent !== null && $recent->created_at !== null
            && $recent->created_at->gt(now()->subSeconds($cooldown))) {
            throw OtpException::resendTooSoon();
        }

        $thisHour = OtpChallenge::query()
            ->where('phone_e164', $e164)
            ->where('created_at', '>=', now()->subHour())
            ->count();

        if ($thisHour >= $hourly) {
            throw OtpException::throttled();
        }

        // Older codes for this number stop working the moment a new one is sent:
        // two valid codes at once doubles the guess space for no benefit.
        OtpChallenge::query()
            ->where('phone_e164', $e164)
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);

        $code = $this->newCode();

        $challenge = OtpChallenge::query()->create([
            'user_id' => $user?->id,
            'phone_e164' => $e164,
            'purpose' => $purpose,
            'code_hash' => Hash::make($code),
            'attempts' => 0,
            'expires_at' => now()->addMinutes($this->number('otp.ttl_minutes', 10)),
            'ip' => $ip,
        ]);

        if (! $this->sender->sendCode($e164, $code)) {
            // A challenge nobody received must not stay usable.
            $challenge->forceFill(['consumed_at' => now()])->save();

            throw OtpException::notDelivered();
        }

        return $challenge;
    }

    /**
     * Checks the code without consuming it; the caller consumes once the account
     * decision is made, so a database error between check and sign-in cannot
     * burn the code.
     *
     * @throws OtpException
     */
    public function verify(string $challengeId, string $code): OtpChallenge
    {
        $challenge = OtpChallenge::query()->find($challengeId);

        if ($challenge === null || $challenge->isSpent()) {
            throw OtpException::invalid();
        }

        if ($challenge->isExpired()) {
            throw OtpException::expired();
        }

        $max = $this->number('otp.max_attempts', 5);

        if ($challenge->attempts >= $max) {
            throw OtpException::tooManyAttempts();
        }

        $digits = (string) preg_replace('/\D/', '', $code);

        if (! Hash::check($digits, $challenge->code_hash)) {
            $challenge->increment('attempts');

            if ($challenge->attempts >= $max) {
                $challenge->forceFill(['consumed_at' => now()])->save();

                throw OtpException::tooManyAttempts();
            }

            throw OtpException::invalid();
        }

        return $challenge;
    }

    public function consume(OtpChallenge $challenge): void
    {
        $challenge->forceFill(['consumed_at' => now()])->save();
    }

    /**
     * A configured number, with a floor.
     *
     * `config()` is mixed, and every one of these values ends up in a
     * computation that must not be handed a string from a mistyped `.env` —
     * `addMinutes('10')` is fine, `addMinutes('ten')` is a crash inside the
     * sign-in path. One place does the reading, so there is one place to be
     * wrong.
     */
    private function number(string $key, int $default): int
    {
        $value = config($key, $default);

        return is_numeric($value) ? (int) $value : $default;
    }

    /** Six digits, leading zeros preserved. */
    private function newCode(): string
    {
        $length = max(4, min(8, $this->number('otp.length', 6)));
        $max = (10 ** $length) - 1;

        return mb_str_pad((string) random_int(0, $max), $length, '0', STR_PAD_LEFT);
    }
}
