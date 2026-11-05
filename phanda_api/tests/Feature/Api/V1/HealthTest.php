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

