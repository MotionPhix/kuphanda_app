<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Malawian mobile numbers, in the one form the database stores.
 *
 * People type their number four different ways — 0991 234 567, 991234567,
 * 265991234567, +265 991 234 567 — and all four are the same subscriber. Storing
 * whatever was typed would create four accounts that cannot be matched, so every
 * path (sign-up, sign-in, linking) normalises exactly here, and WhatsApp receives
 * the digits without the plus.
 */
final class PhoneNumber
{
    /** Malawi. The library is used by schools here; nothing else is assumed. */
    public const COUNTRY_CODE = '265';

    /**
     * E.164, or null when the string is not a usable number.
     *
     * Local shorthand is only expanded for Malawi, because guessing a country
     * for a bare "0788123456" is how a code gets sent to a stranger abroad.
     */
    public static function toE164(?string $raw): ?string
    {
        $value = mb_trim((string) $raw);

        if ($value === '') {
            return null;
        }

        // Keep digits and a leading plus; drop spaces, dashes, brackets, dots.
        $cleaned = (string) preg_replace('/[^0-9+]/', '', $value);

        if ($cleaned === '') {
            return null;
        }

        if (str_starts_with($cleaned, '00')) {
            $cleaned = '+'.mb_substr($cleaned, 2);
        }

        if (str_starts_with($cleaned, '+')) {
            $digits = mb_substr($cleaned, 1);
        } else {
            $digits = $cleaned;

            if (str_starts_with($digits, self::COUNTRY_CODE) && mb_strlen($digits) === 12) {
                // 265991234567
                $digits = mb_substr($digits, 3);
            } elseif (str_starts_with($digits, '0') && mb_strlen($digits) === 10) {
                // 0991234567
                $digits = mb_substr($digits, 1);
            } elseif (mb_strlen($digits) >= 10) {
                // Something long enough to already carry a country code.
                return preg_match('/^[1-9]\d{9,14}$/', $digits) === 1 ? '+'.$digits : null;
            }

            $digits = self::COUNTRY_CODE.$digits;
        }

        $e164 = '+'.$digits;

        if (preg_match('/^\+[1-9]\d{7,14}$/', $e164) !== 1) {
            return null;
        }

        // A Malawian mobile starts 088, 089, 098 or 099 — that is, 8 or 9 after
        // the country code. A landline cannot receive WhatsApp, so it is
        // rejected at the edge instead of failing silently later.
        if (str_starts_with($e164, '+'.self::COUNTRY_CODE)
            && preg_match('/^\+265[89]\d{8}$/', $e164) !== 1) {
            return null;
        }

        return $e164;
    }

    /** WhatsApp wants bare digits; the Cloud API rejects a leading plus. */
    public static function toWhatsApp(?string $e164): string
    {
        return mb_ltrim((string) $e164, '+');
    }

    /**
     * What the screen is allowed to show back: enough to recognise your own
     * number, not enough to be worth harvesting.
     */
    public static function mask(string $e164): string
    {
        $digits = mb_ltrim($e164, '+');

        if (mb_strlen($digits) < 7) {
            return $e164;
        }

        $visible = mb_substr($digits, -3);
        $head = mb_substr($digits, 0, 3);

        return '+'.$head.' ••• ••• '.$visible;
    }
}
