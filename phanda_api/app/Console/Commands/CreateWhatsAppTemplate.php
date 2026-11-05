<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * Creates the AUTHENTICATION template the sign-in codes travel in.
 *
 * The WhatsApp Manager UI can do this, but the authentication body is fixed and
 * its language picker is a combobox that mis-selects under automation: two
 * attempts produced nothing while looking successful. The API is unambiguous —
 * the components below are Meta's documented shape for an authentication
 * template, and the same call can be repeated for the production WABA later.
 *
 * `add_security_recommendation` and `code_expiration_minutes` are what generate
 * the standard body ("…is your verification code. For your security, do not
 * share this code.") and the expiry footer, so nobody types them by hand.
 *
 * Idempotent: if the template already exists in that language it reports the
 * status and exits cleanly, because re-submitting a live template is an error
 * Meta answers with a duplicate-name rejection.
 */
final class CreateWhatsAppTemplate extends Command
{
    protected $signature = 'whatsapp:template
                            {--name=kuphanda_auth_code : Template name, lowercase}
                            {--language=en_US : Template language code}
                            {--ttl=600 : Seconds the code stays valid}';

    protected $description = 'Create the WhatsApp AUTHENTICATION template used for sign-in codes';

    public function handle(): int
    {
        $waba = $this->setting('business_account_id');
        $token = $this->setting('token');
        $version = $this->setting('version', 'v21.0');

        if ($waba === '' || $token === '') {
            $this->error('WHATSAPP_BUSINESS_ACCOUNT_ID and WHATSAPP_TOKEN must be set.');
            $this->line('Run php artisan whatsapp:check to see which value is missing.');

            return self::FAILURE;
        }

        $name = (string) $this->option('name');
        $language = (string) $this->option('language');
        $ttl = (int) $this->option('ttl');

        $this->line("Account {$waba} · {$name} ({$language})");

        $existing = Http::withToken($token)
            ->acceptJson()
            ->timeout(20)
            ->get("https://graph.facebook.com/{$version}/{$waba}/message_templates", [
                'name' => $name,
                'fields' => 'name,status,language,category',
            ]);

        if ($existing->successful()) {
            foreach ((array) $existing->json('data', []) as $row) {
                if (! is_array($row)) {
                    continue;
                }

                if (($row['language'] ?? null) !== $language) {
                    continue;
                }

                $status = is_scalar($row['status'] ?? null) ? (string) $row['status'] : 'unknown';
                $this->info("Already exists — status {$status}.");
                $this->line('Nothing to do. Check it with: php artisan whatsapp:check');

                return self::SUCCESS;
            }
        } else {
            $this->error($this->explain($existing));
            $this->sayHint($existing);

            return self::FAILURE;
        }

        $response = Http::withToken($token)
            ->acceptJson()
            ->timeout(20)
            ->post("https://graph.facebook.com/{$version}/{$waba}/message_templates", [
                'name' => $name,
                'language' => $language,
                'category' => 'AUTHENTICATION',
                // WhatsApp will not deliver a code after this window, which must
                // match OTP_TTL_MINUTES or the app will accept a code the
                // message no longer carries.
                'message_send_ttl_seconds' => $ttl,
                'components' => [
                    ['type' => 'BODY', 'add_security_recommendation' => true],
                    ['type' => 'FOOTER', 'code_expiration_minutes' => (int) ceil($ttl / 60)],
                    ['type' => 'BUTTONS', 'buttons' => [['type' => 'OTP', 'otp_type' => 'COPY_CODE']]],
                ],
            ]);

        if (! $response->successful()) {
            $this->error($this->explain($response));
            $this->sayHint($response);

            return self::FAILURE;
        }

        $status = $response->json('status');
        $id = $response->json('id');

        $this->info('Created — status '.(is_scalar($status) ? (string) $status : 'unknown'));
        $this->line('Template id: '.(is_scalar($id) ? (string) $id : '—'));
        $this->newLine();
        $this->line('Meta reviews authentication templates quickly; usually minutes.');
        $this->line('Verify with: php artisan whatsapp:check');

        return self::SUCCESS;
    }

    private function setting(string $key, string $default = ''): string
    {
        $value = config('services.whatsapp.'.$key, $default);

        if (! is_scalar($value)) {
            return $default;
        }

        $text = (string) $value;

        return $text === '' ? $default : $text;
    }

    /**
     * The actionable half of an error, on its own line.
     *
     * Kept separate so a terminal never has to wrap a 160-character sentence to
     * find out what to do — the same reason the send path splits them.
     */
    private function sayHint(Response $response): void
    {
        $error = $response->json('error');
        $code = is_array($error) ? ($error['code'] ?? null) : null;

        if (! is_numeric($code) || (int) $code !== 190) {
            return;
        }

        $this->line('  → The token expired. Generate a new one, or use a permanent system-user token.');
    }

    private function explain(Response $response): string
    {
        $error = $response->json('error');

        if (! is_array($error)) {
            return 'HTTP '.$response->status().' from graph.facebook.com';
        }

        $message = $error['message'] ?? null;
        $code = $error['code'] ?? null;

        return 'Meta said: '.(is_scalar($message) ? (string) $message : 'rejected')
            .' (code '.(is_scalar($code) ? (string) $code : '?').')';
    }
}
