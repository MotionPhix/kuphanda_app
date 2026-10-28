<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Verifies a Google ID token with Google's tokeninfo endpoint.
 *
 * The audience check is mandatory: without it a token minted for any other
 * Google app could be replayed against this API.
 */
final class GoogleTokenVerifier
{
    /**
     * @return array{sub: string, email: string, email_verified: bool, given_name: string, family_name: string, name: string, picture: string|null}
     */
    public function verify(string $idToken): array
    {
        $clientId = config('services.google.client_id');

        if (! is_string($clientId) || $clientId === '') {
            throw new RuntimeException('Google sign-in is not configured.', 503);
        }

        $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', [
            'id_token' => $idToken,
        ]);

        if (! $response->successful()) {
            throw new RuntimeException('Google could not verify this account.', 401);
        }

        /** @var array<string, mixed> $data */
        $data = $response->json();

        if (($data['aud'] ?? null) !== $clientId) {
            throw new RuntimeException('Google token was issued for another application.', 401);
        }

        $verified = $data['email_verified'] ?? false;
        if ($verified !== true && $verified !== 'true') {
            throw new RuntimeException('Your Google email is not verified.', 401);
        }

        $sub = $data['sub'] ?? null;
        $email = $data['email'] ?? null;

        if (! is_string($sub) || $sub === '' || ! is_string($email) || $email === '') {
            throw new RuntimeException('Google did not return an account id or email.', 401);
        }

        $given = trim((string) ($data['given_name'] ?? ''));
        $family = trim((string) ($data['family_name'] ?? ''));
        $full = trim((string) ($data['name'] ?? ''));

        if ($full === '' && ($given !== '' || $family !== '')) {
            $full = trim($given.' '.$family);
        }

        return [
            'sub' => $sub,
            'email' => strtolower($email),
            'email_verified' => true,
            'given_name' => $given,
            'family_name' => $family,
            'name' => $full,
            'picture' => isset($data['picture']) ? (string) $data['picture'] : null,
        ];
    }
}
