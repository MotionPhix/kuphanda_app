<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\Subject;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    Storage::fake('local');

    Subject::query()->create([
        'id' => 'agriculture',
        'name' => 'Agriculture',
        'short_name' => 'Agric',
        'emoji' => '🌾',
        'color' => '#6B8E23',
        'forms' => [1, 2, 3, 4],
        'blurb' => 'Crops and livestock.',
        'sort_order' => 3,
    ]);
});

function samplePdf(): string
{
    return database_path('seeders/files/weekly-study-planner.pdf');
}

it('adds a document and publishes its first version', function (): void {
    $this->artisan('library:add', [
        'file' => samplePdf(),
        '--title' => 'Form 2 agriculture notes',
        '--subject' => 'agriculture',
        '--form' => 2,
        '--kind' => 'notes',
        '--description' => 'Notes on crop rotation.',
    ])->assertSuccessful();

    $document = Document::query()->find('form-2-agriculture-notes');

    expect($document)->not->toBeNull()
        ->and($document->is_published)->toBeTrue()
        ->and($document->latest_version)->toBe(1)
        ->and($document->pages)->toBeGreaterThan(0)
        ->and($document->versions()->count())->toBe(1);
});

it('refuses a second document with the same id', function (): void {
    $this->artisan('library:add', [
        'file' => samplePdf(),
        '--title' => 'Crop rotation',
        '--subject' => 'agriculture',
    ])->assertSuccessful();

    $this->artisan('library:add', [
        'file' => samplePdf(),
        '--title' => 'Crop rotation',
        '--subject' => 'agriculture',
    ])->assertFailed();

    expect(Document::query()->count())->toBe(1);
});

it('refuses an unknown subject and creates nothing', function (): void {
    $this->artisan('library:add', [
        'file' => samplePdf(),
        '--title' => 'Orphan',
        '--subject' => 'astronomy',
    ])->assertFailed();

    expect(Document::query()->count())->toBe(0);
});

it('refuses a paid tier without a price', function (): void {
    $this->artisan('library:add', [
        'file' => samplePdf(),
        '--title' => 'Paid notes',
        '--subject' => 'agriculture',
        '--tier' => 'weekly',
    ])->assertFailed();

    expect(Document::query()->count())->toBe(0);
});

it('refuses a file that is not a pdf', function (): void {
    $path = sys_get_temp_dir().DIRECTORY_SEPARATOR.'not-a-pdf.txt';
    file_put_contents($path, 'hello');

    $this->artisan('library:add', [
        'file' => $path,
        '--title' => 'Not a paper',
        '--subject' => 'agriculture',
    ])->assertFailed();

    @unlink($path);

    expect(Document::query()->count())->toBe(0);
});
