<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.whatsapp.business_account_id', '1858721421978478');
    config()->set('services.whatsapp.token', 'EAAP7Q5r-temporary-token');
    config()->set('services.whatsapp.version', 'v21.0');
});

it('creates the authentication template with the documented shape', function (): void {
    Http::fake(function ($request) {
        if ($request->method() === 'GET') {
            return Http::response(['data' => []]);
        }

        return Http::response(['id' => '594425479261596', 'status' => 'PENDING'], 200);
    });

    $this->artisan('whatsapp:template')
        ->expectsOutputToContain('Created — status PENDING')
        ->assertExitCode(0);

    Http::assertSent(function ($request) {
        if ($request->method() !== 'POST') {
            return false;
        }

        $body = $request->data();

        return $body['name'] === 'kuphanda_auth_code'
            && $body['language'] === 'en_US'
            && $body['category'] === 'AUTHENTICATION'
            // The expiry the message carries must agree with OTP_TTL_MINUTES.
            && $body['message_send_ttl_seconds'] === 600
            && $body['components'][0]['add_security_recommendation'] === true
            && $body['components'][1]['code_expiration_minutes'] === 10
            && $body['components'][2]['buttons'][0]['otp_type'] === 'COPY_CODE';
    });
});

it('does not resubmit a template that already exists', function (): void {
    Http::fake([
        'graph.facebook.com/*' => Http::response([
            'data' => [[
                'name' => 'kuphanda_auth_code',
                'status' => 'APPROVED',
                'language' => 'en_US',
                'category' => 'AUTHENTICATION',
            ]],
        ]),
    ]);

    $this->artisan('whatsapp:template')
        ->expectsOutputToContain('Already exists — status APPROVED')
        ->assertExitCode(0);

    Http::assertNotSent(fn ($request) => $request->method() === 'POST');
});

it('treats the same name in another language as a different template', function (): void {
    Http::fake(function ($request) {
        if ($request->method() === 'GET') {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_GB',
                ]],
            ]);
        }

        return Http::response(['id' => '594425479261597', 'status' => 'PENDING'], 200);
    });

    $this->artisan('whatsapp:template')
        ->expectsOutputToContain('Created — status PENDING')
        ->assertExitCode(0);
});

it('refuses to run without an account or token', function (): void {
    config()->set('services.whatsapp.business_account_id', '');

    $this->artisan('whatsapp:template')
        ->expectsOutputToContain('must be set')
        ->assertExitCode(1);
});

it('explains an expired token instead of just failing', function (): void {
    Http::fake([
        'graph.facebook.com/*' => Http::response([
            'error' => ['message' => 'Error validating access token: Session has expired', 'code' => 190],
        ], 401),
    ]);

    $this->artisan('whatsapp:template')
        ->expectsOutputToContain('code 190')
        ->expectsOutputToContain('The token expired')
        ->assertExitCode(1);
});
