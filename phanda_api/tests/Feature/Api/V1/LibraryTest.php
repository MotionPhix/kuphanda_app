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
        'blurb' => 'Numbers and algebra.',
        'sort_order' => 1,
    ]);

    $this->user = User::factory()->create(['plan' => LibraryPlan::School]);
    Sanctum::actingAs($this->user);
});

function libraryDocument(array $overrides = [], int $version = 1, string $contents = "%PDF-1.4\n% Kuphanda test\n%%EOF"): Document
{
    $document = Document::query()->create(array_merge([
        'id' => 'doc-'.$version.'-'.uniqid(),
        'subject_id' => 'mathematics',
        'title' => 'Test paper',
        'form' => 4,
        'kind' => 'pastPaper',
        'description' => 'A test document.',
        'pages' => 2,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ], $overrides));

    $path = 'library/documents/'.$document->id.'/v'.$version.'.pdf';
    Storage::disk('local')->put($path, $contents);

    DocumentVersion::query()->create([
        'document_id' => $document->id,
        'version' => $version,
        'disk' => 'local',
        'path' => $path,
        'file_name' => 'paper.pdf',
        'mime_type' => 'application/pdf',
        'size_bytes' => strlen($contents),
        'page_count' => 2,
        'checksum' => hash('sha256', $contents),
        'published_at' => now(),
    ]);

    $document->forceFill([
        'latest_version' => $version,
        'content_updated_at' => now(),
    ])->save();

    return $document->fresh(['currentVersion']);
}

it('requires authentication for the catalogue', function (): void {
    auth()->forgetGuards();

    $this->getJson('/api/v1/documents')->assertStatus(401);
});

it('lists published documents with filters', function (): void {
    libraryDocument(['title' => 'Maths paper']);
    libraryDocument(['title' => 'Biology paper', 'subject_id' => 'mathematics', 'form' => 2]);

    $this->getJson('/api/v1/documents?form=2')
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.title', 'Biology paper');
});

it('marks a document for offline reading', function (): void {
    $document = libraryDocument();

    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201)
        ->assertJsonPath('data.document_id', $document->id)
        ->assertJsonPath('data.current_version.number', 1)
        ->assertJsonPath('data.downloaded_version', null);

    $this->assertDatabaseHas('offline_documents', [
        'user_id' => $this->user->id,
        'document_id' => $document->id,
        'deleted_at' => null,
    ]);
});

it('refuses to download a document that was not marked', function (): void {
    $document = libraryDocument();

    $this->get("/api/v1/library/offline/{$document->id}/download")
        ->assertStatus(409);
});

it('downloads the current file with version metadata and supports conditional requests', function (): void {
    $document = libraryDocument();
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])->assertStatus(201);

    $checksum = $document->currentVersion->checksum;

    $response = $this->get("/api/v1/library/offline/{$document->id}/download");

    $response->assertOk()
        ->assertHeader('X-Document-Version', '1')
        ->assertHeader('X-Document-Checksum', $checksum);

    expect($response->streamedContent())->toContain('%PDF');

    $this->withHeader('If-None-Match', '"'.$checksum.'"')
        ->get("/api/v1/library/offline/{$document->id}/download")
        ->assertStatus(304);
});

it('records the downloaded version', function (): void {
    $document = libraryDocument();
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id]);

    $this->postJson("/api/v1/library/offline/{$document->id}/ack", ['version' => 1])
        ->assertOk()
        ->assertJsonPath('data.downloaded_version', 1)
        ->assertJsonPath('data.update_available', false);
});

it('reports a newer version as an update', function (): void {
    $document = libraryDocument();
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id]);
    $this->postJson("/api/v1/library/offline/{$document->id}/ack", ['version' => 1]);

    $contents = "%PDF-1.4\n% second edition\n%%EOF";
    $path = 'library/documents/'.$document->id.'/v2.pdf';
    Storage::disk('local')->put($path, $contents);
    DocumentVersion::query()->create([
        'document_id' => $document->id,
        'version' => 2,
        'disk' => 'local',
        'path' => $path,
        'file_name' => 'paper-v2.pdf',
        'mime_type' => 'application/pdf',
        'size_bytes' => strlen($contents),
        'page_count' => 3,
        'checksum' => hash('sha256', $contents),
        'published_at' => now(),
    ]);
    $document->forceFill(['latest_version' => 2, 'content_updated_at' => now()])->save();

    $this->getJson('/api/v1/library/offline')
        ->assertOk()
        ->assertJsonPath('data.0.update_available', true)
        ->assertJsonPath('data.0.current_version.number', 2)
        ->assertJsonPath('data.0.downloaded_version', 1);
});

it('removes an offline mark and reports the tombstone on sync', function (): void {
    $document = libraryDocument();
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id]);

    $since = now()->subMinute()->toIso8601String();

    $this->deleteJson("/api/v1/library/offline/{$document->id}")
        ->assertOk();

    $this->getJson('/api/v1/library/sync?since='.urlencode($since))
        ->assertOk()
        ->assertJsonPath('data.removed.0', $document->id);

    $this->assertSoftDeleted('offline_documents', [
        'user_id' => $this->user->id,
        'document_id' => $document->id,
    ]);
});

it('enforces the learner plan for premium documents', function (): void {
    $document = libraryDocument(['access_tier' => 'weekly']);

    $this->user->update(['plan' => LibraryPlan::Free]);
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(403);

    $this->get("/api/v1/library/offline/{$document->id}/download")
        ->assertStatus(403);

    $this->user->update(['plan' => LibraryPlan::School]);
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201);
});

it('does not expose unpublished documents', function (): void {
    $document = libraryDocument(['is_published' => false]);

    $this->getJson('/api/v1/documents')->assertJsonCount(0, 'data');
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(422);
});

it('reuses the mark when a removed document is marked again', function (): void {
    $document = libraryDocument();
    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id]);
    $this->deleteJson("/api/v1/library/offline/{$document->id}")->assertOk();

    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201)
        ->assertJsonPath('data.document_id', $document->id);

    expect(OfflineDocument::query()->where('user_id', $this->user->id)->count())->toBe(1);
});
