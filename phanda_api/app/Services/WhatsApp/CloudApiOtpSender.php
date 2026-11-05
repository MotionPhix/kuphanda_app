<?php

declare(strict_types=1);

namespace App\Services\WhatsApp;

use App\Contracts\OtpSender;
use App\Support\PhoneNumber;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Sends the code through Meta's WhatsApp Cloud API.
 *
 * Kuphanda owns its own WhatsApp Business Account, so there is no provider in
 * the middle: this posts straight to graph.facebook.com with a permanent
 * system-user token. The message must be a template — WhatsApp does not allow
 * free-form text to someone who has not messaged you first — and it must be an
 * AUTHENTICATION template, because that is the only category Meta allows to
 * carry a login code.
 *
 * Everything is configuration, nothing is hard-coded: the template name and its
 * language are read from services.whatsapp, so rotating a template does not
 * need a deploy.
 */
final class CloudApiOtpSender implements OtpSender
{
    public function __construct(
        private readonly string $phoneNumberId,
        private readonly string $token,
        private readonly string $template,
        private readonly string $language = 'en_US',
        private readonly string $version = 'v21.0',
        private readonly bool $codeButton = true,
    ) {}

    public function isConfigured(): bool
    {
        return $this->phoneNumberId !== '' && $this->token !== '' && $this->template !== '';
    }

    public function transport(): string
    {
        return 'whatsapp_cloud_api';
    }

    public function sendCode(string $e164, string $code): bool
    {
        return $this->deliver($e164, $code)['ok'];
    }

    /**
     * The same send, with the detail back.
     *
     * `sendCode` answers yes or no, which is all the sign-in flow needs. Setting
     * the account up needs the third thing: whether Meta accepted the message
     * and which id it gave it, or the sentence behind the rejection. Building
     * the payload twice would let the diagnostic and the real send drift apart,
     * so both go through here.
     *
     * `hint` is kept apart from `error` on purpose: Meta's sentence is what it
     * said, the hint is what to do about it, and a command line that prints them
     * as one 200-character paragraph is a command line nobody reads.
     *
     * @return array{ok: bool, id: string|null, status: int|null, error: string|null, hint: string|null}
     */
    public function deliver(string $e164, string $code): array
    {
        if (! $this->isConfigured()) {
            return [
                'ok' => false,
                'id' => null,
                'status' => null,
                'error' => 'WhatsApp is not configured: phone number ID, token or template is empty.',
                'hint' => 'Set WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_TOKEN and WHATSAPP_OTP_TEMPLATE in .env.',
            ];
        }

        $components = [
            [
                'type' => 'body',
                'parameters' => [['type' => 'text', 'text' => $code]],
            ],
        ];

        // Authentication templates with a "Copy code" button require the code a
        // second time, against button index 0. Sent as a separate component so a
        // template without the button is equally valid.
        if ($this->codeButton) {
            $components[] = [
                'type' => 'button',
                'sub_type' => 'url',
                'index' => '0',
                'parameters' => [['type' => 'text', 'text' => $code]],
            ];
        }

        try {
            $response = Http::withToken($this->token)
                ->acceptJson()
                ->timeout(12)
                ->post(
                    "https://graph.facebook.com/{$this->version}/{$this->phoneNumberId}/messages",
                    [
                        'messaging_product' => 'whatsapp',
                        'recipient_type' => 'individual',
                        'to' => PhoneNumber::toWhatsApp($e164),
                        'type' => 'template',
                        'template' => [
                            'name' => $this->template,
                            'language' => ['code' => $this->language],
                            'components' => $components,
                        ],
                    ]
                );

            if ($response->successful()) {
                $id = $response->json('messages.0.id');

                return [
                    'ok' => true,
                    'id' => is_scalar($id) ? (string) $id : '',
                    'status' => $response->status(),
                    'error' => null,
                    'hint' => null,
                ];
            }

            // 190 = bad/expired token, 132000/132001 = template missing or not
            // approved for this language, 131030 = number not on WhatsApp. The
            // body is the only place those distinctions appear, so log it.
            Log::warning('WhatsApp OTP send failed', [
                'status' => $response->status(),
                'body' => mb_substr($response->body(), 0, 600),
            ]);

            $diagnosis = $this->diagnose($response->json('error'));

            return [
                'ok' => false,
                'id' => null,
                'status' => $response->status(),
                'error' => $diagnosis['message'],
                'hint' => $diagnosis['hint'],
            ];
        } catch (Throwable $exception) {
            Log::warning('WhatsApp OTP send threw', ['error' => $exception->getMessage()]);

            return [
                'ok' => false,
                'id' => null,
                'status' => null,
                'error' => 'Could not reach graph.facebook.com: '.$exception->getMessage(),
                'hint' => 'The host may be blocking outbound HTTPS. Curl graph.facebook.com from the server to check.',
            ];
        }
    }

    /**
     * Turns Meta's error object into a sentence an operator can act on.
     *
     * Graph sends `{"error":{"message":…,"code":1400,…}}` and, for the mistakes
     * that actually happen here, the numeric code is the useful part: 190 is the
     * token, 132001 the template, 131030 the recipient. "Invalid parameter" on
     * its own has cost more hours than any other message in this integration.
     *
     * @return array{message: string, hint: string|null}
     */
    private function diagnose(mixed $error): array
    {
        if (! is_array($error)) {
            return [
                'message' => 'Meta rejected the message without saying why.',
                'hint' => 'Read storage/logs/laravel.log; the response body is logged there.',
            ];
        }

        $code = $error['code'] ?? null;
        $codeNumber = is_numeric($code) ? (int) $code : 0;
        $codeLabel = is_scalar($code) ? (string) $code : '?';

        $rawMessage = $error['message'] ?? null;
        $message = is_scalar($rawMessage) ? (string) $rawMessage : 'No message';

        $data = $error['error_data'] ?? null;
        $detail = is_array($data)
            ? ($data['details'] ?? null)
            : ($error['error_user_msg'] ?? null);

        $sentence = 'Meta said: '.$message.' (code '.$codeLabel.')';

        if (is_string($detail) && $detail !== '') {
            $sentence .= ' — '.$detail;
        }

        $hint = match ($codeNumber) {
            190 => 'The access token is invalid or expired. Use a permanent system-user token.',
            100, 132000, 132001 => 'The template name, language or parameter count does not match what Meta approved.',
            131030 => 'That number is not on WhatsApp, or is not in the test number\'s allowed list.',
            131026 => 'The message is undeliverable — the handset has been offline too long.',
            130429 => 'Sending is rate-limited for this account\'s tier.',
            368 => 'The account is restricted — usually a template that reads as marketing.',
            131042 => 'Billing is not set up on the WhatsApp Business Account.',
            default => null,
        };

        return ['message' => $sentence, 'hint' => $hint];
    }
}
