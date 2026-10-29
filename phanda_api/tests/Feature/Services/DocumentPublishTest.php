<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\Subject;
use App\Services\Library\BlockAudit;
use App\Services\Library\DocumentPublisher;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function structured(array $overrides = []): Document
{
    Subject::query()->firstOrCreate(
        ['id' => 'agriculture'],
        ['name' => 'Agriculture', 'short_name' => 'Agri', 'forms' => [1, 2, 3, 4], 'sort_order' => 1],
    );

    return Document::query()->create(array_merge([
        'id' => 'blocks-'.uniqid(),
        'subject_id' => 'agriculture',
        'title' => 'Test paper',
        'form' => 4,
        'kind' => 'pastPaper',
        'format' => 'blocks',
        'pages' => 4,
        'access_tier' => 'free',
        'is_published' => false,
        'latest_version' => 0,
        'blocks' => [
            'subtitle' => 'Mock paper, 10 marks, 1 hour.',
            'blocks' => [
                [
                    'type' => 'question',
                    'label' => '1.',
                    'marks' => 4,
                    'text' => 'Name two soil types.',
                    'parts' => [
                        ['label' => 'a.', 'text' => 'One.', 'marks' => 2],
                        ['label' => 'b.', 'text' => 'Two.', 'marks' => 2],
                    ],
                ],
            ],
        ],
    ], $overrides));
}

it('reports a paper whose marks do not add up', function (): void {
    $document = structured();
    $report = app(BlockAudit::class)->inspect($document->blocks['blocks'], 'Mock paper, 10 marks');

    expect($report['marks'])->toBe(4)
        ->and($report['issues'])->toHaveCount(1)
        ->and($report['issues'][0])->toContain('short by 6');
});

it('refuses to publish an unreconciled paper', function (): void {
    $document = structured();

    expect(fn () => app(DocumentPublisher::class)->publish($document))
        ->toThrow(RuntimeException::class);

    expect($document->fresh()->is_published)->toBeFalse();
});

it('publishes when the marks reconcile', function (): void {
    $document = structured(['blocks' => [
        'subtitle' => 'Mock paper, 4 marks, 1 hour.',
        'blocks' => [[
            'type' => 'question',
            'label' => '1.',
            'marks' => 4,
            'text' => 'Name two soil types.',
            'parts' => [
                ['label' => 'a.', 'text' => 'One.', 'marks' => 2],
                ['label' => 'b.', 'text' => 'Two.', 'marks' => 2],
            ],
        ]],
    ]]);

    app(DocumentPublisher::class)->publish($document);

    expect($document->fresh()->is_published)->toBeTrue();
});

it('allows a deliberate override', function (): void {
    $document = structured();

    app(DocumentPublisher::class)->publish($document, force: true);

    expect($document->fresh()->is_published)->toBeTrue();
});
