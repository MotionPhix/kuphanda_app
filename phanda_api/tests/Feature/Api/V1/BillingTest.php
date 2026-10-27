<?php

declare(strict_types=1);

use App\Contracts\PaymentGateway;
use App\Enums\LibraryPlan;
use App\Models\Document;
use App\Models\DocumentVersion;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\Subject;
use App\Models\User;
use Database\Seeders\PlanSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

final class FakePaymentGateway implements PaymentGateway
{
    /** @var array<int, array<string, mixed>> */
    public array $initiated = [];

    public bool $verified = true;

    public function initiatePayment(array $data): array
    {
        $this->initiated[] = $data;

        return [
            'success' => true,
            'tx_ref' => $data['tx_ref'],
            'checkout_url' => 'https://checkout.paychangu.test/'.$data['tx_ref'],
            'data' => [],
        ];
    }

    public function verifyTransaction(string $txRef): array
    {
        return [
            'verified' => $this->verified,
            'status' => $this->verified ? 'success' : 'failed',
            'amount' => 100000,
            'currency' => 'MWK',
            'data' => ['tx_ref' => $txRef],
        ];
    }

    public function verifyWebhookSignature(string $payload, string $signature): bool
    {
        return hash_equals(hash_hmac('sha256', $payload, 'test-secret'), $signature);
    }
}

beforeEach(function (): void {
    Storage::fake('local');
    $this->seed(PlanSeeder::class);

    Subject::query()->create([
        'id' => 'mathematics',
        'name' => 'Mathematics',
        'short_name' => 'Maths',
        'emoji' => '📐',
        'color' => '#2F6B9A',
        'forms' => [1, 2, 3, 4],
        'blurb' => 'Numbers.',
        'sort_order' => 1,
    ]);

    $this->user = User::factory()->create(['plan' => LibraryPlan::Free]);
    Sanctum::actingAs($this->user);

    $this->gateway = new FakePaymentGateway;
    $this->app->instance(PaymentGateway::class, $this->gateway);
});

function premiumDocument(array $overrides = []): Document
{
    $document = Document::query()->create(array_merge([
        'id' => 'premium-'.uniqid(),
        'subject_id' => 'mathematics',
        'title' => 'Premium paper',
        'form' => 4,
        'kind' => 'pastPaper',
        'description' => 'A premium document.',
        'pages' => 2,
        'access_tier' => 'weekly',
        'price_mwk' => 2500,
        'is_published' => true,
        'latest_version' => 1,
    ], $overrides));

    $bytes = "%PDF-1.4\n% premium\n%%EOF";
    Storage::disk('local')->put('library/'.$document->id.'.pdf', $bytes);
    DocumentVersion::query()->create([
        'document_id' => $document->id,
        'version' => 1,
        'disk' => 'local',
        'path' => 'library/'.$document->id.'.pdf',
        'file_name' => 'paper.pdf',
        'mime_type' => 'application/pdf',
        'size_bytes' => strlen($bytes),
        'page_count' => 2,
        'checksum' => hash('sha256', $bytes),
        'published_at' => now(),
    ]);

    return $document;
}

it('lists purchasable plans with prices', function (): void {
    $this->getJson('/api/v1/plans')
        ->assertOk()
        ->assertJsonCount(4, 'data')
        ->assertJsonPath('data.0.slug', 'day')
        ->assertJsonPath('data.0.price_mwk', 500);
});

it('shows a paid document as not entitled to a free learner', function (): void {
    premiumDocument();

    $this->getJson('/api/v1/documents')
        ->assertOk()
        ->assertJsonPath('data.0.is_entitled', false)
        ->assertJsonPath('data.0.price_mwk', 2500);
});

it('starts a subscription checkout and activates it after verification', function (): void {
    $document = premiumDocument();
    $plan = Plan::query()->where('slug', 'week')->firstOrFail();

    $checkout = $this->postJson('/api/v1/billing/checkout', ['plan_id' => $plan->id])
        ->assertStatus(201)
        ->assertJsonPath('data.checkout_url', fn (string $url): bool => str_contains($url, 'paychangu'))
        ->json('data');

    expect($this->gateway->initiated)->toHaveCount(1);
    expect($this->gateway->initiated[0]['amount'])->toBe(1500);

    $this->assertDatabaseHas('subscriptions', [
        'tx_ref' => $checkout['tx_ref'],
        'status' => 'pending',
    ]);

    $status = $this->getJson('/api/v1/billing/payments/'.$checkout['tx_ref'])
        ->assertOk()
        ->json('data');

    expect($status['status'])->toBe('active');
    expect($status['entitlement']['tier'])->toBe('weekly');
    expect($status['entitlement']['subscription']['ends_at'])->not->toBeNull();

    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201);
});

it('unlocks a single document through a one-off purchase', function (): void {
    $document = premiumDocument();
    $other = premiumDocument(['access_tier' => 'monthly', 'price_mwk' => 4500]);

    $checkout = $this->postJson('/api/v1/billing/checkout', ['document_id' => $document->id])
        ->assertStatus(201)
        ->json('data');

    $this->getJson('/api/v1/billing/payments/'.$checkout['tx_ref'])->assertOk();

    $this->getJson('/api/v1/documents/'.$document->id)
        ->assertOk()
        ->assertJsonPath('data.is_entitled', true);

    $this->getJson('/api/v1/documents/'.$other->id)
        ->assertOk()
        ->assertJsonPath('data.is_entitled', false);

    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201);
    $this->postJson('/api/v1/library/offline', ['document_id' => $other->id])
        ->assertStatus(403);
});

it('revokes access and flags offline files when a subscription expires', function (): void {
    $document = premiumDocument();
    $plan = Plan::query()->where('slug', 'week')->firstOrFail();

    $subscription = Subscription::query()->create([
        'user_id' => $this->user->id,
        'plan_id' => $plan->id,
        'status' => 'active',
        'tx_ref' => 'SUB-EXPIRE',
        'amount_mwk' => 1500,
        'starts_at' => now()->subDays(8),
        'ends_at' => now()->addDay(),
        'paid_at' => now()->subDays(8),
    ]);

    $this->postJson('/api/v1/library/offline', ['document_id' => $document->id])
        ->assertStatus(201);
    $this->get("/api/v1/library/offline/{$document->id}/download")->assertOk();

    $subscription->update(['ends_at' => now()->subMinute()]);

    $this->getJson('/api/v1/library/offline')
        ->assertOk()
        ->assertJsonPath('data.0.is_entitled', false);

    $this->get("/api/v1/library/offline/{$document->id}/download")
        ->assertStatus(403);
});

it('accepts a signed PayChangu webhook and rejects an unsigned one', function (): void {
    $plan = Plan::query()->where('slug', 'day')->firstOrFail();
    $checkout = $this->postJson('/api/v1/billing/checkout', ['plan_id' => $plan->id])
        ->assertStatus(201)
        ->json('data');

    $payload = json_encode([
        'tx_ref' => $checkout['tx_ref'],
        'status' => 'success',
        'amount' => 500,
        'currency' => 'MWK',
    ], JSON_THROW_ON_ERROR);

    $this->call(
        'POST',
        '/api/v1/webhooks/paychangu',
        [],
        [],
        [],
        ['HTTP_Signature' => 'wrong', 'CONTENT_TYPE' => 'application/json'],
        $payload
    )->assertStatus(401);

    $signature = hash_hmac('sha256', $payload, 'test-secret');

    $this->call(
        'POST',
        '/api/v1/webhooks/paychangu',
        [],
        [],
        [],
        ['HTTP_Signature' => $signature, 'CONTENT_TYPE' => 'application/json'],
        $payload
    )->assertOk();

    expect(Subscription::query()->where('tx_ref', $checkout['tx_ref'])->firstOrFail()->status)
        ->toBe(\App\Enums\SubscriptionStatus::Active);
});

it('lists receipts for subscriptions and purchases without leaking other learners', function (): void {
    $plan = Plan::query()->where('slug', 'week')->firstOrFail();
    $document = premiumDocument();

    Subscription::query()->create([
        'user_id' => $this->user->id,
        'plan_id' => $plan->id,
        'status' => 'active',
        'tx_ref' => 'SUB-RECEIPT',
        'amount_mwk' => 1500,
        'starts_at' => now(),
        'ends_at' => now()->addWeek(),
        'paid_at' => now(),
    ]);

    \App\Models\DocumentPurchase::query()->create([
        'user_id' => $this->user->id,
        'document_id' => $document->id,
        'status' => 'paid',
        'tx_ref' => 'DOC-RECEIPT',
        'amount_mwk' => 2500,
        'purchased_at' => now(),
    ]);

    $other = User::factory()->create(['plan' => LibraryPlan::Free]);
    \App\Models\DocumentPurchase::query()->create([
        'user_id' => $other->id,
        'document_id' => $document->id,
        'status' => 'paid',
        'tx_ref' => 'DOC-OTHER',
        'amount_mwk' => 2500,
        'purchased_at' => now(),
    ]);

    $response = $this->getJson('/api/v1/billing/payments')
        ->assertOk()
        ->assertJsonCount(2, 'data');

    $refs = collect($response->json('data'))->pluck('tx_ref')->all();

    expect($refs)->toContain('SUB-RECEIPT')->toContain('DOC-RECEIPT')
        ->not->toContain('DOC-OTHER');
});

it('refuses a second checkout while a subscription is active', function (): void {
    $plan = Plan::query()->where('slug', 'week')->firstOrFail();
    $checkout = $this->postJson('/api/v1/billing/checkout', ['plan_id' => $plan->id])->json('data');
    $this->getJson('/api/v1/billing/payments/'.$checkout['tx_ref'])->assertOk();

    $this->postJson('/api/v1/billing/checkout', ['plan_id' => $plan->id])
        ->assertStatus(409);
});

