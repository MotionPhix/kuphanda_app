<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Contracts\OtpSender;
use App\Services\WhatsApp\CloudApiOtpSender;
use App\Support\PhoneNumber;
use Illuminate\Console\Command;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * One command that says which piece of the WhatsApp setup is wrong.
 *
 * Setting this up means five values copied from three different Meta screens,
 * and every mistake produces the same thing from the API: a rejection the
 * learner never sees and the operator only finds in a log line. Rather than
 * guess, this checks each layer in the order it can fail — configuration, then
 * the token against the phone number, then the template's approval, then an
 * actual send — and stops describing what it cannot see.
 *
 * It never prints the token, and it sends nothing unless asked with --send.
 */
final class CheckWhatsApp extends Command
{
    protected $signature = 'whatsapp:check
                            {--send= : Send a real test code to this number, e.g. 0991234567}
                            {--code=123456 : The digits to put in the test message}';

    protected $description = 'Check WhatsApp sign-in configuration, credentials, template and delivery';

    public function handle(OtpSender $sender): int
    {
        $this->line('WhatsApp sign-in — configuration');
        $this->newLine();

        $values = [
            'WHATSAPP_PHONE_NUMBER_ID' => $this->setting('phone_number_id'),
            'WHATSAPP_TOKEN' => $this->setting('token'),
            'WHATSAPP_OTP_TEMPLATE' => $this->setting('template'),
            'WHATSAPP_OTP_LANGUAGE' => $this->setting('language'),
            'WHATSAPP_BUSINESS_ACCOUNT_ID' => $this->setting('business_account_id'),
        ];

        foreach ($values as $key => $value) {
            if ($value === '') {
                $this->line("  [ ] {$key} — not set");

                continue;
            }

            $this->line("  [x] {$key} = ".($key === 'WHATSAPP_TOKEN' ? $this->maskToken($value) : $value));
        }

        $this->line('  [x] WHATSAPP_OTP_CODE_BUTTON = '.(config('services.whatsapp.code_button') ? 'true' : 'false'));

        if (! $sender->isConfigured()) {
            $this->newLine();
            $this->error('Phone sign-in is OFF: a required value above is empty.');
            $this->line('Email and Google keep working — /auth/otp/start answers 503 and the app says so.');
            $this->line('Fill .env, then: php artisan config:clear && php artisan config:cache');

            return self::FAILURE;
        }

        $version = $this->setting('version', 'v21.0');
        $numberId = $this->setting('phone_number_id');
        $token = $this->setting('token');
        $template = $this->setting('template');
        $language = $this->setting('language', 'en_US');
        $waba = $this->setting('business_account_id');

        $healthy = true;

        $this->newLine();
        $this->line('Number and token');

        // A read against the number itself proves both at once: the id exists and
        // the token may see it. A 404 here means the display number was pasted
        // instead of the id, which is the most common mistake in this integration.
        $number = Http::withToken($token)
            ->acceptJson()
            ->timeout(15)
            ->get("https://graph.facebook.com/{$version}/{$numberId}", [
                'fields' => 'display_phone_number,verified_name,quality_rating',
            ]);

        if ($number->successful()) {
            // The payload is mixed all the way through, so each field is read
            // defensively: a missing one prints a dash rather than "Array".
            $label = static function (mixed $value, string $fallback = '—'): string {
                return is_scalar($value) && (string) $value !== '' ? (string) $value : $fallback;
            };

            $this->info('  '.$label($number->json('display_phone_number'))
                .' — '.$label($number->json('verified_name'), 'unnamed')
                .' (quality: '.$label($number->json('quality_rating'), 'unknown').')');
        } else {
            $healthy = false;
            $this->error('  '.$this->explain($number));

            if ($number->status() === 404) {
                $this->line('  The phone number ID is not the display number. Copy it from WhatsApp → API Setup.');
            }
        }

        $this->newLine();
        $this->line('Template');

        if ($waba === '') {
            $this->line('  not checked — set WHATSAPP_BUSINESS_ACCOUNT_ID to read its approval status.');
        } else {
            $templates = Http::withToken($token)
                ->acceptJson()
                ->timeout(15)
                ->get("https://graph.facebook.com/{$version}/{$waba}/message_templates", [
                    'name' => $template,
                    'fields' => 'name,status,language,category',
                ]);

            if (! $templates->successful()) {
                $healthy = false;
                $this->error('  '.$this->explain($templates));
            } else {
                $status = null;
                $category = null;

                foreach ((array) $templates->json('data', []) as $row) {
                    if (! is_array($row)) {
                        continue;
                    }

                    if (($row['name'] ?? null) === $template && ($row['language'] ?? null) === $language) {
                        $status = is_scalar($row['status'] ?? null) ? (string) $row['status'] : '';
                        $category = is_scalar($row['category'] ?? null) ? (string) $row['category'] : '?';

                        break;
                    }
                }

                if ($status === null) {
                    $healthy = false;
                    $this->error("  no template named {$template} in {$language}.");
                    $this->line('  Create it under WhatsApp Manager → Message templates, category Authentication.');
                } elseif ($status !== 'APPROVED') {
                    $healthy = false;
                    $this->error("  {$template} ({$language}) is ".($status === '' ? 'unknown' : $status).', not APPROVED.');
                } else {
                    $this->info("  {$template} ({$language}) — APPROVED, category {$category}");
                }
            }
        }

        $target = (string) $this->option('send');

        if ($target !== '') {
            $this->newLine();
            $this->line('Real send');

            $e164 = PhoneNumber::toE164($target);

            if ($e164 === null) {
                $this->error('  '.$target.' is not a usable mobile number.');

                return self::FAILURE;
            }

            $code = (string) $this->option('code');

            if ($sender instanceof CloudApiOtpSender) {
                $result = $sender->deliver($e164, $code);

                if ($result['ok']) {
                    $this->info('  sent to '.PhoneNumber::mask($e164).' — message id '.$result['id']);
                } else {
                    $healthy = false;
                    $this->error('  '.$result['error']);

                    if ($result['hint'] !== null) {
                        $this->line('  → '.$result['hint']);
                    }
                }
            } elseif ($sender->sendCode($e164, $code)) {
                $this->info('  sent to '.PhoneNumber::mask($e164));
            } else {
                $healthy = false;
                $this->error('  the sender refused. Check the log.');
            }
        }

        $this->newLine();

        if (! $healthy) {
            $this->error('Something above needs fixing. Sign-in stays off until it is.');

            return self::FAILURE;
        }

        $this->info($target === ''
            ? 'Ready. Add --send=09xxxxxxxx to prove delivery.'
            : 'Ready, and a message was accepted by Meta.');

        return self::SUCCESS;
    }

    /** One place that reads a `services.whatsapp.*` value as a string. */
    private function setting(string $key, string $default = ''): string
    {
        $value = config('services.whatsapp.'.$key, $default);

        if (! is_scalar($value)) {
            return $default;
        }

        $text = (string) $value;

        return $text === '' ? $default : $text;
    }

    /** Enough of the token to tell two apart, not enough to use one. */
    private function maskToken(string $token): string
    {
        if (mb_strlen($token) <= 10) {
            return str_repeat('•', mb_strlen($token));
        }

        return mb_substr($token, 0, 6).'…'.mb_substr($token, -4).' ('.mb_strlen($token).' chars)';
    }

    private function explain(Response $response): string
    {
        $error = $response->json('error');

        if (is_array($error)) {
            $message = $error['message'] ?? null;
            $code = $error['code'] ?? null;

            return 'Meta said: '.(is_scalar($message) ? (string) $message : 'rejected')
                .' (code '.(is_scalar($code) ? (string) $code : '?').')';
        }

        return 'HTTP '.$response->status().' from graph.facebook.com';
    }
}
