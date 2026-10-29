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
it('counts nested sub-parts and ignores unmarked containers', function (): void {
    $blocks = [[
        'type' => 'question',
        'label' => '7.',
        'marks' => 6,
        'text' => 'Table 1 shows farm gate and retail prices.',
        'parts' => [[
            'label' => 'i.',
            'text' => 'Calculate the marketing margins for each crop:',
            'marks' => null,
            'parts' => [
                ['label' => '(1)', 'text' => 'Irish potatoes', 'marks' => 2],
                ['label' => '(2)', 'text' => 'Onions.', 'marks' => 2],
            ],
        ], [
            'label' => 'ii.',
            'text' => '',
            'marks' => null,
            'parts' => [
                ['label' => '(1)', 'text' => 'Which produce has the smaller margin?', 'marks' => 1],
                ['label' => '(2)', 'text' => 'State one possible cause.', 'marks' => 1],
            ],
        ]],
    ]];

    $report = app(BlockAudit::class)->inspect($blocks, 'Mock paper, 6 marks');

    expect($report['marks'])->toBe(6)
        ->and($report['issues'])->toBe([]);
});

it('flags a nested leaf that has no mark', function (): void {
    $blocks = [[
        'type' => 'question',
        'label' => '3.',
        'marks' => null,
        'text' => 'Seed treatment.',
        'parts' => [[
            'label' => 'a.',
            'text' => 'Importance of each:',
            'parts' => [
                ['label' => 'i.', 'text' => 'Scarification', 'marks' => 1],
                ['label' => 'ii.', 'text' => 'Inoculation'],
            ],
        ]],
    ]];

    $report = app(BlockAudit::class)->inspect($blocks);

    expect($report['marks'])->toBe(1)
        ->and($report['issues'])->toHaveCount(1)
        ->and($report['issues'][0])->toContain('1 part(s) without marks');
});
it('reports a question with no allocation and no parts', function (): void {
    $blocks = [[
        'type' => 'question',
        'label' => '13.',
        'marks' => null,
        'text' => 'Given that 2x, x, x + 3 are terms in an AP, find x.',
        'parts' => [],
    ]];

    $report = app(BlockAudit::class)->inspect($blocks, 'Paper I, 100 marks');

    expect($report['marks'])->toBe(0)
        ->and($report['issues'])->toContain('13.: no mark allocation')
        ->and($report['issues'])->toHaveCount(2);
});
