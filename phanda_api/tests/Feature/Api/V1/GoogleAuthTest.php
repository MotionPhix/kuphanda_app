<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    config(['services.google.client_id' => 'test-client.apps.googleusercontent.com']);

    $this->googleStatus = 200;
    $this->googlePayload = [
        'sub' => 'google-sub-123',
        'email' => 'learner@example.com',
        'email_verified' => 'true',
        'given_name' => 'Chisomo',
        'family_name' => 'Banda',
        'name' => 'Chisomo Banda',
        'picture' => 'https://example.com/avatar.png',
        'aud' => 'test-client.apps.googleusercontent.com',
    ];

    Http::fake(fn () => Http::response($this->googlePayload, $this->googleStatus));
});

it('creates a learner from a verified Google account', function (): void {
    $response = $this->postJson('/api/v1/auth/google', ['id_token' => str_repeat('a', 40)]);

    $response->assertOk()
        ->assertJsonPath('data.user.email', 'learner@example.com')
        ->assertJsonPath('data.user.first_name', 'Chisomo')
        ->assertJsonPath('data.user.last_name', 'Banda')
        ->assertJsonPath('data.user.google_linked', true);

    $user = User::query()->where('email', 'learner@example.com')->firstOrFail();
    expect($user->google_id)->toBe('google-sub-123')
        ->and($user->first_name)->toBe('Chisomo')
        ->and($user->last_name)->toBe('Banda')
        ->and($user->email_verified_at)->not->toBeNull();
});

it('links Google to an existing email account without overwriting names', function (): void {
    $existing = User::factory()->create([
        'name' => 'My Chosen Name',
        'first_name' => 'My',
        'last_name' => 'Name',
        'email' => 'learner@example.com',
        'plan' => 'school',
    ]);

    $this->postJson('/api/v1/auth/google', ['id_token' => str_repeat('b', 40)])
        ->assertOk()
        ->assertJsonPath('data.user.id', $existing->id);

    $existing->refresh();
    expect($existing->google_id)->toBe('google-sub-123')
        ->and($existing->first_name)->toBe('My')
        ->and($existing->last_name)->toBe('Name')
        ->and($existing->name)->toBe('My Chosen Name')
        ->and($existing->plan->value)->toBe('school');
});

it('fills blank names from Google on an existing account', function (): void {
    $existing = User::factory()->create([
        'name' => '',
        'first_name' => null,
        'last_name' => null,
        'email' => 'learner@example.com',
    ]);

    $this->postJson('/api/v1/auth/google', ['id_token' => str_repeat('c', 40)])
        ->assertOk();

    $existing->refresh();
    expect($existing->first_name)->toBe('Chisomo')
        ->and($existing->last_name)->toBe('Banda')
        ->and($existing->name)->toBe('Chisomo Banda');
});

it('rejects a token issued for another application', function (): void {
    $this->googlePayload['aud'] = 'someone-else.apps.googleusercontent.com';

    $this->postJson('/api/v1/auth/google', ['id_token' => str_repeat('d', 40)])
        ->assertStatus(401);
});

it('rejects an unverified token', function (): void {
    $this->googleStatus = 400;
    $this->googlePayload = [];

    $this->postJson('/api/v1/auth/google', ['id_token' => str_repeat('e', 40)])
        ->assertStatus(401);
});
