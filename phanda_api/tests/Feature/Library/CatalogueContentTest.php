<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\Plan;
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

    // The guides' sections ship inside the app; the catalogue still has to list
    // them, or an online learner sees a smaller library than an offline one.
    /** @var array{guides: array<int, array{id: string}>} $guides */
    $guides = json_decode((string) file_get_contents(database_path('seeders/files/guides.json')), true);

    foreach ($guides['guides'] as $guide) {
        expect(Document::query()->find('guide-'.$guide['id']))->not->toBeNull(
            'guide-'.$guide['id'].' is missing from the catalogue',
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

    // Documents without prices leave the subscription page empty, which is
    // what it looked like when only the catalogue seeders ran.
    expect(Plan::query()->count())->toBeGreaterThan(0);
})->group('library');

it('finds documents by subject, tag and year, not only by title', function (): void {
    catalogueSubject();

    Subject::query()->create([
        'id' => 'biology',
        'name' => 'Biology',
        'short_name' => 'Biology',
        'emoji' => '🧬',
        'color' => '#2E7D4F',
        'forms' => [3, 4],
        'blurb' => 'Cells and genetics.',
        'sort_order' => 2,
    ]);

    bareDocument('cells-paper', [
        'subject_id' => 'biology',
        'title' => 'Cell structure and transport',
        'tags' => ['genetics', 'paper 2'],
        'year' => 2024,
        'paper_number' => 2,
    ])->forceFill(['latest_version' => 1])->save();

    bareDocument('maths-paper', ['title' => 'Algebra practice']);

    Sanctum::actingAs(User::factory()->create());

    $this->getJson('/api/v1/documents?q=Biology')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.id', 'cells-paper');

    $this->getJson('/api/v1/documents?q=genetics')
        ->assertOk()
        ->assertJsonPath('data.0.id', 'cells-paper');

    $this->getJson('/api/v1/documents?q=2024')
        ->assertOk()
        ->assertJsonPath('data.0.id', 'cells-paper');
})->group('library');

