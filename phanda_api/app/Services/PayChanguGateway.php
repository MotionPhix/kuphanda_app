<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\PaymentGateway;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * PayChangu implementation, following the same contract as the web reference:
 * POST /payment to initiate, GET /verify-payment/{tx_ref} to confirm, and an
 * HMAC-SHA256 signature on webhook payloads.
 */
final class PayChanguGateway implements PaymentGateway
{
    private string $baseUrl;

    private string $secretKey;

    private string $webhookSecret;

    public function __construct()
    {
        $this->baseUrl = rtrim((string) config('services.paychangu.base_url', 'https://api.paychangu.com'), '/');
        $this->secretKey = (string) config('services.paychangu.secret_key', '');
        $this->webhookSecret = (string) config('services.paychangu.webhook_secret', '');
    }

    public function initiatePayment(array $data): array
    {
        if ($this->secretKey === '') {
            return [
                'success' => false,
                'message' => 'Card and mobile money payments are not configured on this server.',
            ];
        }

        $txRef = (string) ($data['tx_ref'] ?? 'TX-'.Str::uuid());

        $payload = [
            'amount' => (int) $data['amount'],
            'currency' => $data['currency'] ?? config('services.paychangu.currency', 'MWK'),
            'email' => $data['email'],
            'first_name' => $data['first_name'] ?? '',
            'last_name' => $data['last_name'] ?? '',
            'callback_url' => $data['callback_url'],
            'return_url' => $data['return_url'],
            'tx_ref' => $txRef,
            'customization' => [
                'title' => $data['title'] ?? 'Kuphanda subscription',
                'description' => $data['description'] ?? 'Kuphanda library access',
            ],
            'meta' => $data['meta'] ?? [],
        ];

        try {
            $response = Http::withHeaders([
                'Accept' => 'application/json',
                'Authorization' => 'Bearer '.$this->secretKey,
            ])->timeout(20)->post($this->baseUrl.'/payment', $payload);

            if ($response->successful()) {
                $body = $response->json();

                return [
                    'success' => true,
                    'tx_ref' => $txRef,
                    'checkout_url' => $body['data']['checkout_url'] ?? null,
                    'data' => is_array($body) ? $body : [],
                ];
            }

            Log::warning('PayChangu initiation failed', [
                'status' => $response->status(),
                'tx_ref' => $txRef,
            ]);

            return [
                'success' => false,
                'message' => $this->providerMessage($response),
            ];
        } catch (\Throwable $exception) {
            Log::error('PayChangu initiation error', ['message' => $exception->getMessage()]);

            return [
                'success' => false,
                'message' => 'The payment provider could not be reached. Try again.',
            ];
        }
    }

    public function verifyTransaction(string $txRef): array
    {
        if ($this->secretKey === '') {
            return ['verified' => false, 'message' => 'Payments are not configured.'];
        }

        try {
            $response = Http::withHeaders([
                'Accept' => 'application/json',
                'Authorization' => 'Bearer '.$this->secretKey,
            ])->timeout(20)->get($this->baseUrl.'/verify-payment/'.$txRef);

            if (! $response->successful()) {
                return ['verified' => false, 'message' => $this->providerMessage($response)];
            }

            $body = $response->json();
            $data = $body['data'] ?? [];
            $status = strtolower((string) ($data['status'] ?? ''));

            return [
                'verified' => $status === 'success',
                'status' => $status,
                'amount' => isset($data['amount']) ? (float) $data['amount'] : null,
                'currency' => $data['currency'] ?? null,
                'data' => is_array($data) ? $data : [],
            ];
        } catch (\Throwable $exception) {
            Log::error('PayChangu verification error', ['message' => $exception->getMessage()]);

            return ['verified' => false, 'message' => 'Could not verify the payment yet.'];
        }
    }

    public function verifyWebhookSignature(string $payload, string $signature): bool
    {
        if ($this->webhookSecret === '' || $signature === '') {
            return false;
        }

        return hash_equals(hash_hmac('sha256', $payload, $this->webhookSecret), $signature);
    }

    private function providerMessage(Response $response): string
    {
        $body = $response->json();

        return (string) ($body['message'] ?? 'The payment provider rejected the request.');
    }
}
