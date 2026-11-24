<?php

use App\Models\Document;
use App\Models\Subject;
use Database\Seeders\RevisionGuidesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    // documents.subject_id is a foreign key, so the guide cannot exist without
    // the subject row.
    Subject::query()->create([
        'id' => 'mathematics',
        'name' => 'Mathematics',
        'short_name' => 'Maths',
        'emoji' => '📐',
        'color' => '#2F6B9A',
        'forms' => [1, 2, 3, 4],
    ]);
});

/**
 * These two guides are the only content that exercises the whole block schema,
 * so the seeder is where that coverage is pinned: if a block type quietly
 * disappears from the JSON, the reader loses its only live test.
 */
it('publishes both revision guides as free block documents', function (): void {
    $this->seed(RevisionGuidesSeeder::class);

    $guides = Document::query()
        ->whereIn('id', ['ref-guide-circle-geometry', 'ref-guide-data-handling'])
        ->get();

    expect($guides)->toHaveCount(2);

    foreach ($guides as $guide) {
        expect($guide->format)->toBe('blocks')
            ->and($guide->kind)->toBe('guide')
            ->and($guide->is_published)->toBeTrue()
            ->and($guide->access_tier)->toBe(App\Enums\AccessTier::Free)
            ->and($guide->author)->toBe('Kuphanda')
            // No year or paper number: these are not examination papers and must
            // not read as if they were.
            ->and($guide->year)->toBeNull()
            ->and($guide->paper_number)->toBeNull()
            ->and($guide->blocks['blocks'] ?? [])->not->toBeEmpty();
    }
});

it('covers every block type the reader renders', function (): void {
    $this->seed(RevisionGuidesSeeder::class);

    $types = Document::query()
        ->whereIn('id', ['ref-guide-circle-geometry', 'ref-guide-data-handling'])
        ->get()
        ->flatMap(fn (Document $guide) => collect($guide->blocks['blocks'] ?? [])->pluck('type'))
        ->unique()
        ->sort()
        ->values()
        ->all();

    expect($types)->toBe([
        'answer',
        'bullets',
        'callout',
        'divider',
        'figure',
        'heading',
        'paragraph',
        'question',
        'table',
    ]);
});

it('ships a drawn figure rather than an image that would not exist on the device', function (): void {
    $this->seed(RevisionGuidesSeeder::class);

    $figure = collect(Document::query()->find('ref-guide-circle-geometry')->blocks['blocks'])
        ->firstWhere('type', 'figure');

    expect($figure)->not->toBeNull()
        // A drawn figure carries points and a circle; an asset figure names a
        // file, and naming one that is not bundled renders a placeholder.
        ->and($figure['figure']['points'] ?? [])->not->toBeEmpty()
        ->and($figure['figure']['circle'] ?? null)->not->toBeNull()
        ->and($figure['figure']['asset'] ?? null)->toBeNull();
});
