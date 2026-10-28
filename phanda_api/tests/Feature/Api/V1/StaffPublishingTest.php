<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\DocumentVersion;
use App\Models\Subject;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
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
        'color' => '#1D4ED8',
        'forms' => [1, 2, 3, 4],
        'blurb' => 'Numbers and proof.',
        'sort_order' => 1,
    ]);

    $this->document = Document::query()->create([
        'id' => 'staff-publish-target',
        'title' => 'Staff publish target',
        'subject_id' => 'mathematics',
        'form' => 4,
        'kind' => 'notes',
        'pages' => 1,
        'access_tier' => 'free',
        'latest_version' => 0,
        'is_published' => true,
    ]);

    $this->path = tempnam(sys_get_temp_dir(), 'staff_pdf_').'.pdf';
    file_put_contents($this->path, "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF");
});

afterEach(function (): void {
    @unlink($this->path);
});

it('forbids learners from the staff publishing endpoints', function (): void {
    $user = User::factory()->create(['is_staff' => false]);
    Sanctum::actingAs($user);

    $this->getJson('/api/v1/staff/documents')->assertStatus(403);
    $this->postJson('/api/v1/staff/documents/'.$this->document->id.'/versions')
        ->assertStatus(403);
});

it('lets staff upload a new version through media library', function (): void {
    $staff = User::factory()->create(['is_staff' => true]);
    Sanctum::actingAs($staff);

    $response = $this->post(
        '/api/v1/staff/documents/'.$this->document->id.'/versions',
        [
            'file' => new UploadedFile($this->path, 'guide.pdf', 'application/pdf', null, true),
            'pages' => 3,
            'notes' => 'First upload',
        ],
        ['Accept' => 'application/json'],
    );

    $response->assertCreated()
        ->assertJsonPath('data.number', 1)
        ->assertJsonPath('data.page_count', 3);

    $version = DocumentVersion::query()->where('document_id', $this->document->id)->firstOrFail();

    expect($version->media_id)->not->toBeNull()
        ->and($version->media->mime_type)->toBe('application/pdf')
        ->and($this->document->fresh()->latest_version)->toBe(1);

    Storage::disk('local')->assertExists($version->media_id.'/'.$version->media->file_name);

    $this->getJson('/api/v1/staff/documents')
        ->assertOk()
        ->assertJsonPath('data.0.latest_version', 1)
        ->assertJsonPath('data.0.media_count', 1);
});

it('rejects a non-pdf upload', function (): void {
    $staff = User::factory()->create(['is_staff' => true]);
    Sanctum::actingAs($staff);

    $this->post(
        '/api/v1/staff/documents/'.$this->document->id.'/versions',
        [
            'file' => UploadedFile::fake()->create('notes.txt', 2, 'text/plain'),
            'pages' => 1,
        ],
        ['Accept' => 'application/json'],
    )->assertStatus(422);
});

it('lets staff withdraw a document and restores it', function (): void {
    $staff = User::factory()->create(['is_staff' => true]);
    Sanctum::actingAs($staff);

    $this->patchJson('/api/v1/staff/documents/'.$this->document->id.'/publication', [
        'is_published' => false,
    ])->assertOk();

    $this->getJson('/api/v1/documents')->assertOk()->assertJsonCount(0, 'data');

    $this->patchJson('/api/v1/staff/documents/'.$this->document->id.'/publication', [
        'is_published' => true,
    ])->assertOk();
});
