<?php

declare(strict_types=1);

use App\Enums\LibraryPlan;
use App\Models\Document;
use App\Models\DocumentVersion;
use App\Models\OfflineDocument;
use App\Models\Subject;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    Storage::fake('local');

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

    $this->document = Document::query()->create([
        'id' => 'publish-target',
        'subject_id' => 'mathematics',
        'title' => 'Publishing target',
        'form' => 4,
        'kind' => 'notes',
        'description' => 'Test document.',
        'pages' => 2,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ]);

    $this->pdf = tempnam(sys_get_temp_dir(), 'kuphanda').'.pdf';
    file_put_contents($this->pdf, "%PDF-1.4\n1 0 obj\n<< /Type /Page >>\nendobj\n%%EOF");
});

afterEach(function (): void {
    if (isset($this->pdf) && is_file($this->pdf)) {
        unlink($this->pdf);
    }
});

it('publishes a first version with checksum and page count', function (): void {
    $this->artisan('library:publish', [
        'document' => 'publish-target',
        'file' => $this->pdf,
        '--pages' => 2,
        '--notes' => 'First release',
    ])->assertSuccessful();

    $version = DocumentVersion::query()->where('document_id', 'publish-target')->firstOrFail();

    expect($version->version)->toBe(1)
        ->and($version->size_bytes)->toBe(filesize($this->pdf))
        ->and($version->checksum)->toBe(hash('sha256', file_get_contents($this->pdf)))
        ->and($version->page_count)->toBe(2)
        ->and($version->notes)->toBe('First release');

    Storage::disk('local')->assertExists($version->path);

    $this->document->refresh();
    expect($this->document->latest_version)->toBe(1)
        ->and($this->document->is_published)->toBeTrue()
        ->and($this->document->content_updated_at)->not->toBeNull();
});

it('bumps the version instead of overwriting a published file', function (): void {
    $this->artisan('library:publish', ['document' => 'publish-target', 'file' => $this->pdf, '--pages' => 2])
        ->assertSuccessful();

    file_put_contents($this->pdf, "%PDF-1.4\n% second edition\n1 0 obj\n<< /Type /Page >>\nendobj\n%%EOF");

    $this->artisan('library:publish', ['document' => 'publish-target', 'file' => $this->pdf, '--pages' => 3])
        ->assertSuccessful();

    expect(DocumentVersion::query()->where('document_id', 'publish-target')->count())->toBe(2);
    expect($this->document->fresh()->latest_version)->toBe(2);
});

it('rejects a file that is not a PDF', function (): void {
    file_put_contents($this->pdf, 'plain text, not a pdf');

    $this->artisan('library:publish', ['document' => 'publish-target', 'file' => $this->pdf])
        ->assertFailed();

    expect(DocumentVersion::query()->count())->toBe(0);
});

it('rejects an unknown document', function (): void {
    $this->artisan('library:publish', ['document' => 'missing', 'file' => $this->pdf])
        ->assertFailed();

    expect(DocumentVersion::query()->count())->toBe(0);
});

it('revokes offline entitlement when a document is unpublished', function (): void {
    $this->artisan('library:publish', ['document' => 'publish-target', 'file' => $this->pdf, '--pages' => 2])
        ->assertSuccessful();

    $user = User::factory()->create(['plan' => LibraryPlan::School]);
    Sanctum::actingAs($user);

    $this->postJson('/api/v1/library/offline', ['document_id' => 'publish-target'])->assertStatus(201);

    $this->artisan('library:unpublish', ['document' => 'publish-target'])->assertSuccessful();

    $this->getJson('/api/v1/documents')->assertOk()->assertJsonCount(0, 'data');
    $this->getJson('/api/v1/library/offline')
        ->assertOk()
        ->assertJsonPath('data.0.is_entitled', false);

    $this->get('/api/v1/library/offline/publish-target/download')->assertStatus(404);

    expect(OfflineDocument::query()->count())->toBe(1);
});
