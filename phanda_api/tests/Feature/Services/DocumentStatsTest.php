<?php

declare(strict_types=1);

use App\Http\Resources\DocumentResource;
use App\Models\Document;
use App\Models\Subject;
use App\Services\Library\DocumentStats;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function statsDocument(array $overrides = []): Document
{
    Subject::query()->firstOrCreate(
        ['id' => 'mathematics'],
        ['name' => 'Mathematics', 'short_name' => 'Maths', 'forms' => [1, 2, 3, 4], 'sort_order' => 1],
    );

    return Document::query()->create(array_merge([
        'id' => 'stats-'.uniqid(),
        'subject_id' => 'mathematics',
        'title' => 'Paper I',
        'form' => 4,
        'kind' => 'pastPaper',
        'format' => 'blocks',
        'pages' => 6,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
        'blocks' => [
            'subtitle' => 'Paper I, 9 marks, 2 hours.',
            'blocks' => [
                ['type' => 'callout', 'text' => 'Answer all questions.'],
                [
                    'type' => 'question',
                    'label' => '1.',
                    'marks' => 4,
                    'text' => 'Simplify.',
                    'parts' => [
                        ['label' => 'a.', 'text' => 'First.', 'marks' => 2],
                        ['label' => 'b.', 'text' => 'Second.', 'marks' => 2],
                    ],
                ],
                ['type' => 'question', 'label' => '2.', 'marks' => 5, 'text' => 'Solve.', 'parts' => []],
            ],
        ],
    ], $overrides));
}

it('counts questions and marks rather than pages', function (): void {
    $document = statsDocument();
    $stats = app(DocumentStats::class)->for($document);

    expect($stats)->not->toBeNull()
        ->and($stats['questions'])->toBe(2)
        ->and($stats['marks'])->toBe(9);
});

it('reports nothing to count for a document with no blocks', function (): void {
    $document = statsDocument(['blocks' => null, 'format' => 'pdf']);

    expect(app(DocumentStats::class)->for($document))->toBeNull();
});

it('exposes the counts so the app can stop saying "6 pages"', function (): void {
    $document = statsDocument();

    $payload = (new DocumentResource($document))->resolve();

    expect($payload['pages'])->toBe(6)
        ->and($payload['questions'])->toBe(2)
        ->and($payload['block_marks'])->toBe(9);
});

it('reports the papers we ship in the units their subtitle promises', function (string $file, int $questions, int $marks): void {
    // Pinned against the seeded payloads, not a fixture: if an edit changes how
    // many questions a paper has, the number a learner reads changes with it and
    // this fails first.
    $payload = json_decode((string) file_get_contents(database_path('seeders/files/'.$file)), true);

    $document = statsDocument(['blocks' => $payload]);
    $stats = app(DocumentStats::class)->for($document);

    expect($stats['questions'])->toBe($questions)
        ->and($stats['marks'])->toBe($marks);
})->with([
    'maths 2002 paper I' => ['blocks-msce-maths-2002-p1.json', 24, 100],
    'agriculture 2017 paper I' => ['blocks-msce-agriculture-2017-p1.json', 14, 100],
]);
