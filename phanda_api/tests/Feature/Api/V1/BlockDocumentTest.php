<?php

declare(strict_types=1);

use App\Models\Document;
use App\Models\Plan;
use App\Models\Subject;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\PlanSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function blockDocument(array $overrides = []): Document
{
    Subject::query()->firstOrCreate(
        ['id' => $overrides['subject_id'] ?? 'mathematics'],
        ['name' => 'Mathematics', 'short_name' => 'Maths', 'forms' => [1, 2, 3, 4], 'sort_order' => 1],
    );

    return Document::query()->create(array_merge([
        'id' => 'blocks-'.uniqid(),
        'subject_id' => 'mathematics',
        'title' => 'Mechanics workbook',
        'form' => 4,
        'kind' => 'notes',
        'format' => 'hybrid',
        'blocks' => [
            'subtitle' => 'Sample pilot document',
            'blocks' => [
                ['type' => 'heading', 'text' => 'Kinematics'],
                ['type' => 'question', 'marks' => 4, 'text' => 'Calculate the acceleration.'],
            ],
        ],
        'pages' => 3,
        'access_tier' => 'free',
        'price_mwk' => 0,
        'is_published' => true,
        'latest_version' => 0,
    ], $overrides));
}

it('serves structured blocks to an entitled learner', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $document = blockDocument();

    $this->getJson("/api/v1/documents/{$document->id}/blocks")
        ->assertOk()
        ->assertJsonPath('data.title', 'Mechanics workbook')
        ->assertJsonPath('data.format', 'hybrid')
        ->assertJsonPath('data.source_version', 0)
        ->assertJsonCount(2, 'data.blocks');
});

it('exposes the format on the document resource', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $document = blockDocument();

    $this->getJson("/api/v1/documents/{$document->id}")
        ->assertOk()
        ->assertJsonPath('data.format', 'hybrid')
        ->assertJsonPath('data.has_blocks', true);
});

it('hides blocks behind the same entitlement as the file', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $document = blockDocument(['access_tier' => 'weekly', 'price_mwk' => 2500]);

    $this->getJson("/api/v1/documents/{$document->id}/blocks")->assertForbidden();
});

it('serves blocks once the learner subscribes', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $this->seed(PlanSeeder::class);

    $document = blockDocument(['access_tier' => 'weekly', 'price_mwk' => 2500]);
    $plan = Plan::query()->where('slug', 'week')->firstOrFail();

    Subscription::query()->create([
        'user_id' => $user->id,
        'plan_id' => $plan->id,
        'status' => 'active',
        'tx_ref' => 'SUB-BLOCKS',
        'amount_mwk' => 1500,
        'starts_at' => now()->subDay(),
        'ends_at' => now()->addDays(6),
        'paid_at' => now()->subDay(),
    ]);

    $this->getJson("/api/v1/documents/{$document->id}/blocks")
        ->assertOk()
        ->assertJsonCount(2, 'data.blocks');
});

it('reports a document with no structured version', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $document = blockDocument(['format' => 'pdf', 'blocks' => null]);

    $this->getJson("/api/v1/documents/{$document->id}/blocks")->assertNotFound();
});

it('requires authentication', function (): void {
    $document = blockDocument();

    $this->getJson("/api/v1/documents/{$document->id}/blocks")->assertUnauthorized();
});

it('does not serve a draft document', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $document = blockDocument(['is_published' => false]);

    $this->getJson("/api/v1/documents/{$document->id}/blocks")->assertNotFound();
});
