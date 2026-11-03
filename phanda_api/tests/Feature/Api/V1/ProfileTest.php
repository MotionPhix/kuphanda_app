<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->user = User::factory()->create(['name' => 'Old Name', 'email' => 'old@example.com']);
    Sanctum::actingAs($this->user);
});

it('updates first and last name and rebuilds the display name', function (): void {
    $this->patchJson('/api/v1/me', [
        'first_name' => 'Chisomo',
        'last_name' => 'Banda',
        'school' => 'Bwaila Secondary School',
    ])
        ->assertOk()
        ->assertJsonPath('data.first_name', 'Chisomo')
        ->assertJsonPath('data.last_name', 'Banda')
        ->assertJsonPath('data.name', 'Chisomo Banda')
        ->assertJsonPath('data.school', 'Bwaila Secondary School');

    $this->user->refresh();
    expect($this->user->name)->toBe('Chisomo Banda')
        ->and($this->user->first_name)->toBe('Chisomo')
        ->and($this->user->last_name)->toBe('Banda')
        ->and($this->user->email)->toBe('old@example.com');
});

it('allows clearing the school', function (): void {
    $this->user->update(['school' => 'Some School']);

    $this->patchJson('/api/v1/me', ['school' => null])
        ->assertOk()
        ->assertJsonPath('data.school', null);
});

it('validates name lengths', function (): void {
    $this->patchJson('/api/v1/me', ['first_name' => str_repeat('a', 81)])
        ->assertStatus(422);
});

it('requires authentication', function (): void {
    $this->app['auth']->forgetGuards();

    $this->patchJson('/api/v1/me', ['first_name' => 'No', 'last_name' => 'Auth'])
        ->assertStatus(401);
});

it('records onboarding as complete once the answers are there', function (): void {
    $this->patchJson('/api/v1/me', [
        'first_name' => 'Tadala',
        'last_name' => 'Phiri',
        'role' => 'student',
        'form' => 3,
    ])
        ->assertOk()
        ->assertJsonPath('data.role', 'student')
        ->assertJsonPath('data.form', 3)
        ->assertJsonPath('data.profile_completed', true);

    expect($this->user->refresh()->profile_completed_at)->not->toBeNull();
});

it('leaves a learner incomplete until a form is chosen', function (): void {
    $this->patchJson('/api/v1/me', [
        'first_name' => 'Tadala',
        'last_name' => 'Phiri',
        'role' => 'student',
    ])
        ->assertOk()
        ->assertJsonPath('data.profile_completed', false);
});

it('completes a teacher without a form', function (): void {
    $this->patchJson('/api/v1/me', [
        'first_name' => 'Grace',
        'last_name' => 'Mwale',
        'role' => 'teacher',
    ])
        ->assertOk()
        ->assertJsonPath('data.role', 'teacher')
        ->assertJsonPath('data.profile_completed', true);
});

it('keeps completion once recorded, even when a later edit clears a field', function (): void {
    $this->user->forceFill(['profile_completed_at' => now()->subDay()])->save();

    $this->patchJson('/api/v1/me', ['school' => null])
        ->assertOk()
        ->assertJsonPath('data.profile_completed', true);
});

