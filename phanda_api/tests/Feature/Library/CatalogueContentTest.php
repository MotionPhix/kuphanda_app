<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\OfflineDocument;
use App\Models\Subject;
use App\Models\User;
use App\Services\Library\DocumentReadiness;
use Database\Seeders\BlockDocumentSeeder;
use Database\Seeders\LibrarySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function catalogueSubject(): Subject
{
    return Subject::query()->create([
        'id' => 'mathematics',
        'name' => 'Mathematics',
        'short_name' => 'Maths',
        'emoji' => '📐',
        'color' => '#2F6B9A',
        'forms' => [1, 2, 3, 4],
        'blurb' => 'Numbers and algebra.',
        'sort_order' => 1,
    ]);
}

function bareDocument(string $id, array $overrides = []): Document
{
    return Document::query()->create(array_merge([
        'id' => $id,
        'subject_id' => 'mathematics',
        'title' => 'Metadata only',
        'form' => 4,
        'kind' => 'pastPaper',
        'description' => 'A record with no content behind it.',
        'pages' => 20,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ], $overrides));
}

it('seeds a catalogue in which every published document can be opened', function (): void {
    Storage::fake('local');
    catalogueSubject();

    $this->seed(LibrarySeeder::class);
    $this->seed(BlockDocumentSeeder::class);

    $readiness = app(DocumentReadiness::class);
    $published = Document::query()->where('is_published', true)->get();

    expect($published)->not->toBeEmpty();

    foreach ($published as $document) {
        expect($readiness->isReadable($document))->toBeTrue(
            "{$document->id} is published but has nothing to read",
        );
    }
})->group('library');

it('keeps the retired placeholder out of a freshly seeded catalogue', function (): void {
    Storage::fake('local');
    catalogueSubject();

    bareDocument('ref-msce-biology-2023-paper2');

    $this->seed(LibrarySeeder::class);

    expect(Document::query()->find('ref-msce-biology-2023-paper2'))->toBeNull();
})->group('library');

it('does not list a published record with nothing to read', function (): void {
    catalogueSubject();
    bareDocument('metadata-only');

    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $this->getJson('/api/v1/documents')
        ->assertOk()
        ->assertJsonCount(0, 'data');
})->group('library');

it('prunes placeholders and keeps a record somebody has acted on', function (): void {
    catalogueSubject();
    bareDocument('unused-placeholder');
    bareDocument('marked-for-offline');

    $user = User::factory()->create();
    OfflineDocument::query()->create([
        'user_id' => $user->id,
        'document_id' => 'marked-for-offline',
        'marked_at' => now(),
    ]);

    $this->artisan('library:prune', ['--delete' => true])->assertSuccessful();

    expect(Document::query()->find('unused-placeholder'))->toBeNull()
        ->and(Document::query()->find('marked-for-offline'))->not->toBeNull()
        ->and(Document::query()->find('marked-for-offline')->is_published)->toBeFalse();
})->group('library');

it('reports placeholders without deleting them unless asked', function (): void {
    catalogueSubject();
    bareDocument('still-here');

    $this->artisan('library:prune')->assertSuccessful();

    expect(Document::query()->find('still-here'))->not->toBeNull();
})->group('library');

it('restores the code-owned catalogue with library:sync', function (): void {
    Storage::fake('local');
    catalogueSubject();

    $this->artisan('library:sync')->assertSuccessful();

    $published = Document::query()->where('is_published', true)->get();

    expect($published->count())->toBeGreaterThanOrEqual(12)
        ->and($published->pluck('id'))->toContain('guide-bio-genetics', 'sample-howto');
})->group('library');
