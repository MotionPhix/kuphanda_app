<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\Subject;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('reports the catalogue and the integrations without authentication', function (): void {
    Subject::query()->create([
        'id' => 'mathematics',
        'name' => 'Mathematics',
        'short_name' => 'Maths',
        'emoji' => '📐',
        'color' => '#2F6B9A',
        'forms' => [1, 2, 3, 4],
        'blurb' => 'Numbers.',
        'sort_order' => 1,
    ]);

    Document::query()->create([
        'id' => 'readable-paper',
        'subject_id' => 'mathematics',
        'title' => 'Algebra',
        'form' => 4,
        'kind' => 'notes',
        'description' => 'Worked examples.',
        'pages' => 4,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 1,
    ]);

    Document::query()->create([
        'id' => 'unreadable-row',
        'subject_id' => 'mathematics',
        'title' => 'Nothing behind this',
        'form' => 4,
        'kind' => 'notes',
        'description' => 'No content.',
        'pages' => 4,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ]);

    config(['services.google.client_id' => null]);

    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('status', 'ok')
        ->assertJsonPath('catalogue.published', 2)
        ->assertJsonPath('catalogue.readable', 1)
        ->assertJsonPath('catalogue.unreadable', 1)
        ->assertJsonPath('features.google_sign_in', false)
        // No service account in the test environment, so class notifications
        // can only reach a phone that is already open. Saying so is the point.
        ->assertJsonPath('features.push.configured', false)
        ->assertJsonPath('catalogue.plans', 0)
        ->assertJsonStructure(['time', 'features' => ['mail_transport', 'push']]);
});

it('reports google sign-in as configured once a client id is present', function (): void {
    config(['services.google.client_id' => '239327365893-test.apps.googleusercontent.com']);

    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('features.google_sign_in', true);
});

// Two tests, not one with a refresh: the sender is resolved once per request
// from configuration, and the in-memory database does not survive an app
// reboot. A fresh test gets a fresh container without either problem.
it('reports phone sign-in as off when WhatsApp is not configured', function (): void {
    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('features.whatsapp_otp.configured', false)
        ->assertJsonPath('features.whatsapp_otp.transport', 'none');
});

it('reports phone sign-in as configured once the credentials exist', function (): void {
    config([
        'services.whatsapp.phone_number_id' => '1339113705962983',
        'services.whatsapp.token' => 'EAAP7Q5r-token',
        'services.whatsapp.template' => 'kuphanda_auth_code',
    ]);

    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertJsonPath('features.whatsapp_otp.configured', true)
        ->assertJsonPath('features.whatsapp_otp.transport', 'whatsapp_cloud_api')
        ->assertJsonPath('features.whatsapp_otp.template', 'kuphanda_auth_code');
});

it('reports the commit recorded at deploy time', function (): void {
    $path = storage_path('app/current-commit');
    @unlink($path);

    $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('commit', null);

    file_put_contents($path, "4ddb1ea\n");

    try {
        $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('commit', '4ddb1ea');
    } finally {
        @unlink($path);
    }
})->group('health');
