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
