<?php

declare(strict_types=1);

namespace App\Services\Push;

use App\Contracts\PushSender;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Firebase Cloud Messaging over the HTTP v1 API.
 *
 * Authentication uses a service-account JSON key, exchanged for a short-lived
 * OAuth2 access token with an RS256-signed JWT. The key never leaves the
 * server: it is read from a path outside the public directory and the access
 * token is cached until just before it expires.
 */
final class FirebasePushSender implements PushSender
{
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    private const ANDROID_CHANNEL = 'kuphanda_default';

    public function __construct(
        private readonly string $projectId,
        private readonly string $credentialsPath,
    ) {}

    public function isConfigured(): bool
    {
        return $this->projectId !== '' && is_file($this->credentialsPath);
    }

    public function sendToToken(string $token, array $payload): bool
    {
        return $this->send(['token' => $token] + $this->message($payload));
    }

    public function sendToTopic(string $topic, array $payload): bool
    {
        return $this->send(['topic' => $topic] + $this->message($payload));
    }

    /**
     * @param  array{title: string, body: string, data?: array<string, mixed>}  $payload
     * @return array<string, mixed>
     */
    private function message(array $payload): array
    {
        $data = [];
        foreach ($payload['data'] ?? [] as $key => $value) {
            if ($value === null) {
                continue;
            }
            $data[(string) $key] = is_scalar($value)
                ? (string) $value
                : (string) json_encode($value);
        }

        return [
            'notification' => [
                'title' => $payload['title'],
                'body' => $payload['body'],
            ],
            'data' => $data,
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'channel_id' => self::ANDROID_CHANNEL,
                ],
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                    ],
                ],
            ],
        ];
    }

    /**
     * @param  array<string, mixed>  $message
     */
    private function send(array $message): bool
    {
        if (! $this->isConfigured()) {
            return false;
        }

        try {
            $response = Http::withToken($this->accessToken())
                ->acceptJson()
                ->timeout(10)
                ->post(
                    "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send",
                    ['message' => $message],
                );

            if ($response->successful()) {
                return true;
            }

            // A revoked token would otherwise be retried forever.
            if ($response->status() === 404) {
                $this->forgetAccessToken();
            }

            Log::warning('FCM send failed', [
                'status' => $response->status(),
                'body' => $response->json('error.status') ?? $response->body(),
            ]);

            return false;
        } catch (\Throwable $error) {
            Log::warning('FCM send error: '.$error->getMessage());

            return false;
        }
    }

    private function accessToken(): string
    {
        $key = $this->cacheKey();
        $cached = Cache::get($key);

        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $credentials = $this->credentials();
        $now = time();

        $jwt = $this->sign([
            'iss' => $credentials['client_email'],
            'scope' => self::SCOPE,
            'aud' => self::TOKEN_URL,
            'iat' => $now,
            'exp' => $now + 3600,
        ], $credentials['private_key']);

        $response = Http::asForm()
            ->timeout(10)
            ->post(self::TOKEN_URL, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

        if (! $response->successful()) {
            throw new RuntimeException(
                'Could not authorise with Firebase: '.$response->status()
            );
        }

        $token = (string) $response->json('access_token');
        $expiresIn = (int) ($response->json('expires_in') ?? 3600);

        if ($token === '') {
            throw new RuntimeException('Firebase returned an empty access token.');
        }

        Cache::put($key, $token, max(60, $expiresIn - 120));

        return $token;
    }

    private function forgetAccessToken(): void
    {
        Cache::forget($this->cacheKey());
    }

    private function cacheKey(): string
    {
        return 'firebase:access_token:'.$this->projectId;
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    private function sign(array $claims, string $privateKey): string
    {
        $header = ['alg' => 'RS256', 'typ' => 'JWT'];

        $segments = [
            $this->base64Url((string) json_encode($header, JSON_THROW_ON_ERROR)),
            $this->base64Url((string) json_encode($claims, JSON_THROW_ON_ERROR)),
        ];

        $signature = '';
        $ok = openssl_sign(
            implode('.', $segments),
            $signature,
            $privateKey,
            OPENSSL_ALGO_SHA256,
        );

        if (! $ok) {
            throw new RuntimeException('Could not sign the Firebase JWT.');
        }

        $segments[] = $this->base64Url($signature);

        return implode('.', $segments);
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    /**
     * @return array{client_email: string, private_key: string}
     */
    private function credentials(): array
    {
        $raw = @file_get_contents($this->credentialsPath);

        if ($raw === false) {
            throw new RuntimeException('Firebase credentials could not be read.');
        }

        /** @var array<string, mixed>|null $json */
        $json = json_decode($raw, true);

        $email = is_array($json) ? ($json['client_email'] ?? null) : null;
        $key = is_array($json) ? ($json['private_key'] ?? null) : null;

        if (! is_string($email) || $email === '' || ! is_string($key) || $key === '') {
            throw new RuntimeException('Firebase credentials are incomplete.');
        }

        return ['client_email' => $email, 'private_key' => $key];
    }
}
