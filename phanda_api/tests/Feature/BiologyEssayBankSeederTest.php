<?php

use App\Enums\AccessTier;
use App\Models\Document;
use App\Models\Subject;
use Database\Seeders\BiologyEssayBankSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    Subject::query()->create([
        'id' => 'biology',
        'name' => 'Biology',
        'short_name' => 'Biology',
        'emoji' => '🧬',
        'color' => '#2E7D4F',
        'forms' => [3, 4],
    ]);
});

$bank = function (): Document {
    test()->seed(BiologyEssayBankSeeder::class);

    return Document::query()->findOrFail('ref-biology-essay-bank');
};

it('publishes the essay bank as free study notes', function () use ($bank): void {
    $document = $bank();

    expect($document->subject_id)->toBe('biology')
        ->and($document->kind)->toBe('notes')
        ->and($document->format)->toBe('blocks')
        ->and($document->access_tier)->toBe(AccessTier::Free)
        ->and($document->is_published)->toBeTrue()
        ->and($document->author)->toBe('Target Private Secondary School')
        // Transcribed revision material, not an examination paper: claiming a
        // year or paper number would say an exam board set it.
        ->and($document->year)->toBeNull()
        ->and($document->paper_number)->toBeNull();
});

it('keeps every question readable and every topic in the bank', function () use ($bank): void {
    $blocks = collect($bank()->blocks['blocks']);

    $questions = $blocks->where('type', 'question');
    $headings = $blocks->where('type', 'heading');

    expect($questions)->toHaveCount(60)
        ->and($headings)->toHaveCount(15)
        // A question card with no wording is a blank card in the reader.
        ->and($questions->filter(fn ($block) => trim($block['text'] ?? '') === ''))->toBeEmpty()
        ->and($questions->filter(fn ($block) => ! isset($block['page'])))->toBeEmpty();

    // Most questions carry the source's model answer; the rest are still worth
    // planning, which is why they are kept as cards rather than dropped.
    $answered = $questions->filter(fn ($block) => ! empty($block['items']));
    expect($answered->count())->toBeGreaterThanOrEqual(50);
});

it('opens with guidance on how to study from it', function () use ($bank): void {
    $blocks = collect($bank()->blocks['blocks']);

    expect($blocks->first()['type'])->toBe('callout')
        ->and($blocks->first()['text'])->toContain('Show answers');
});
