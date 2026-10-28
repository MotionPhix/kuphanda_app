<?php

declare(strict_types=1);

use App\Services\Push\FirebasePushSender;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

function serviceAccountFile(): string
{
    $options = [
        'private_key_bits' => 2048,
        'private_key_type' => OPENSSL_KEYTYPE_RSA,
    ];

    // Windows PHP builds often cannot locate openssl.cnf on their own.
    foreach ([
        dirname(PHP_BINARY).'/extras/ssl/openssl.cnf',
        dirname(PHP_BINARY).'/extras/openssl/openssl.cnf',
    ] as $candidate) {
        if (is_file($candidate)) {
            $options['config'] = $candidate;

            break;
        }
    }

    $key = openssl_pkey_new($options);

    expect($key)->not->toBeFalse();

    $exported = openssl_pkey_export($key, $pem, null, $options);

    expect($exported)->toBeTrue()->and($pem)->not->toBeEmpty();

    $path = tempnam(sys_get_temp_dir(), 'fcm').'.json';

    file_put_contents($path, json_encode([
        'type' => 'service_account',
        'project_id' => 'kuphanda-app',
        'client_email' => 'push@kuphanda-app.iam.gserviceaccount.com',
        'private_key' => $pem,
    ]));

    return $path;
}

it('exchanges a signed assertion for an access token and sends to a token', function (): void {
    $path = serviceAccountFile();

    Http::fake([
        '*oauth2.googleapis.com/token*' => Http::response([
            'access_token' => 'ya29.test',
            'expires_in' => 3600,
        ]),
        '*fcm.googleapis.com/*' => Http::response(['name' => 'projects/kuphanda-app/messages/1']),
    ]);

    $sender = new FirebasePushSender('kuphanda-app', $path);

    $ok = $sender->sendToToken('device-token-1234567890', [
        'title' => 'New paper',
        'body' => 'Form 3 maths is ready',
        'data' => ['category' => 'document', 'document_id' => 'maths-3'],
    ]);

    expect($ok)->toBeTrue();

    Http::assertSent(function (Request $request): bool {
        if ($request->url() !== 'https://oauth2.googleapis.com/token') {
            return false;
        }

        $assertion = (string) ($request->data()['assertion'] ?? '');

        // Three JWT segments: header, claims, signature.
        return $request->data()['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            && count(explode('.', $assertion)) === 3;
    });

    Http::assertSent(function (Request $request): bool {
        if (! str_contains($request->url(), 'fcm.googleapis.com/v1/projects/kuphanda-app/messages:send')) {
            return false;
        }

        $message = $request->data()['message'] ?? [];

        return $request->hasHeader('Authorization', 'Bearer ya29.test')
            && ($message['token'] ?? null) === 'device-token-1234567890'
            && ($message['notification']['title'] ?? null) === 'New paper'
            && ($message['data']['document_id'] ?? null) === 'maths-3'
            && ($message['android']['notification']['channel_id'] ?? null) === 'kuphanda_default';
    });

    @unlink($path);
});

it('sends a broadcast to a topic', function (): void {
    $path = serviceAccountFile();

    Http::fake([
        '*oauth2.googleapis.com/token*' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3600]),
        '*fcm.googleapis.com/*' => Http::response(['name' => 'projects/kuphanda-app/messages/2']),
    ]);

    $sender = new FirebasePushSender('kuphanda-app', $path);

    expect($sender->sendToTopic('students', ['title' => 'Hi', 'body' => 'All students']))->toBeTrue();

    Http::assertSent(fn (Request $request): bool => str_contains($request->url(), 'messages:send')
        && ($request->data()['message']['topic'] ?? null) === 'students');

    @unlink($path);
});

it('reports failure instead of throwing when FCM rejects a message', function (): void {
    $path = serviceAccountFile();

    Http::fake([
        '*oauth2.googleapis.com/token*' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3600]),
        '*fcm.googleapis.com/*' => Http::response(['error' => ['status' => 'NOT_FOUND']], 404),
    ]);

    $sender = new FirebasePushSender('kuphanda-app', $path);

    expect($sender->sendToToken('stale-token-1234567890', ['title' => 'Hi', 'body' => 'x']))->toBeFalse();

    @unlink($path);
});
