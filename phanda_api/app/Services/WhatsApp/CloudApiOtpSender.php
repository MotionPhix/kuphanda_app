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
        if (! $this->isConfigured()) {
            return false;
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
                return true;
            }

            // 190 = bad/expired token, 132000/132001 = template missing or not
            // approved for this language, 131030 = number not on WhatsApp. The
            // body is the only place those distinctions appear, so log it.
            Log::warning('WhatsApp OTP send failed', [
                'status' => $response->status(),
                'body' => mb_substr($response->body(), 0, 600),
            ]);

            return false;
        } catch (Throwable $exception) {
            Log::warning('WhatsApp OTP send threw', ['error' => $exception->getMessage()]);

            return false;
        }
    }
}
