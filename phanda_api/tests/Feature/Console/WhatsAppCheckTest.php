<?php

declare(strict_types=1);

use Illuminate\Support\Facades\Http;

/**
 * The command exists so an operator does not have to read Graph error codes.
 * These tests pin the two things that matters about it: it names the broken
 * layer, and it never prints the token.
 */
beforeEach(function (): void {
    config()->set('services.whatsapp.phone_number_id', '123456789012345');
    config()->set('services.whatsapp.token', 'EAAG-super-secret-token-value-9f8e7d');
    config()->set('services.whatsapp.template', 'kuphanda_auth_code');
    config()->set('services.whatsapp.language', 'en_US');
    config()->set('services.whatsapp.business_account_id', '987654321098765');
    config()->set('services.whatsapp.version', 'v21.0');
    config()->set('services.whatsapp.code_button', true);
});

it('says phone sign-in is off when a required value is missing', function (): void {
    config()->set('services.whatsapp.token', '');

    $this->artisan('whatsapp:check')
        ->expectsOutputToContain('WHATSAPP_TOKEN — not set')
        ->expectsOutputToContain('Phone sign-in is OFF')
        ->assertExitCode(1);
});

it('passes when the number, the token and an approved template all answer', function (): void {
    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_US',
                    'category' => 'AUTHENTICATION',
                ]],
            ]);
        }

        return Http::response([
            'display_phone_number' => '+265 99 123 4567',
            'verified_name' => 'Kuphanda Library',
            'quality_rating' => 'GREEN',
        ]);
    });

    $this->artisan('whatsapp:check')
        ->expectsOutputToContain('Kuphanda Library')
        ->expectsOutputToContain('APPROVED')
        ->expectsOutputToContain('Ready.')
        ->assertExitCode(0);
});

it('never prints the token', function (): void {
    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_US',
                ]],
            ]);
        }

        return Http::response(['display_phone_number' => '+265 99 123 4567']);
    });

    $this->artisan('whatsapp:check')
        ->doesntExpectOutputToContain('super-secret-token')
        ->expectsOutputToContain('EAAG-s…8e7d')
        ->assertExitCode(0);
});

it('names a wrong phone number id, which is a 404 from Graph', function (): void {
    Http::fake([
        'graph.facebook.com/*' => Http::response([
            'error' => [
                'message' => 'Unsupported get request. Object does not exist',
                'code' => 100,
            ],
        ], 404),
    ]);

    $this->artisan('whatsapp:check')
        ->expectsOutputToContain('code 100')
        ->expectsOutputToContain('not the display number')
        ->assertExitCode(1);
});

it('reports a template that has not been approved yet', function (): void {
    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'PENDING',
                    'language' => 'en_US',
                ]],
            ]);
        }

        return Http::response(['display_phone_number' => '+265 99 123 4567']);
    });

    $this->artisan('whatsapp:check')
        ->expectsOutputToContain('PENDING, not APPROVED')
        ->assertExitCode(1);
});

it('reports a template that exists in another language only', function (): void {
    config()->set('services.whatsapp.language', 'ny_MW');

    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_US',
                ]],
            ]);
        }

        return Http::response(['display_phone_number' => '+265 99 123 4567']);
    });

    $this->artisan('whatsapp:check')
        ->expectsOutputToContain('no template named kuphanda_auth_code in ny_MW')
        ->assertExitCode(1);
});

it('sends a real code when asked, and reports the message id', function (): void {
    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_US',
                    'category' => 'AUTHENTICATION',
                ]],
            ]);
        }

        if (str_ends_with($request->url(), '/messages')) {
            return Http::response(['messages' => [['id' => 'wamid.TEST123']]], 200);
        }

        return Http::response(['display_phone_number' => '+265 99 123 4567']);
    });

    $this->artisan('whatsapp:check', ['--send' => '0991234567'])
        ->expectsOutputToContain('wamid.TEST123')
        ->assertExitCode(0);
});

it('explains a rejected send instead of just failing', function (): void {
    Http::fake(function ($request) {
        if (str_contains($request->url(), 'message_templates')) {
            return Http::response([
                'data' => [[
                    'name' => 'kuphanda_auth_code',
                    'status' => 'APPROVED',
                    'language' => 'en_US',
                ]],
            ]);
        }

        if (str_ends_with($request->url(), '/messages')) {
            return Http::response([
                'error' => [
                    'message' => 'Template name does not exist in the translation',
                    'code' => 132001,
                    'error_data' => ['details' => 'Missing template kuphanda_auth_code in en_US'],
                ],
            ], 400);
        }

        return Http::response(['display_phone_number' => '+265 99 123 4567']);
    });

    $this->artisan('whatsapp:check', ['--send' => '0991234567'])
        ->expectsOutputToContain('code 132001')
        ->expectsOutputToContain('does not match what Meta approved')
        ->assertExitCode(1);
});

it('refuses to send to a number that is not a mobile', function (): void {
    Http::fake();

    $this->artisan('whatsapp:check', ['--send' => '021234567'])
        ->expectsOutputToContain('not a usable mobile number')
        ->assertExitCode(1);
});
