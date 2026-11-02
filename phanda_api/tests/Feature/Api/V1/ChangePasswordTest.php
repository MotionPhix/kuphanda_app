<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

describe('Changing a password while signed in', function (): void {
    it('changes it and keeps the phone that asked', function (): void {
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $phone = $user->createToken('phone')->plainTextToken;
        $user->createToken('tablet');

        $this->withToken($phone)
            ->putJson('/api/v1/password', [
                'current_password' => 'old-password',
                'password' => 'new-password-9',
                'password_confirmation' => 'new-password-9',
            ])
            ->assertOk();

        expect(Hash::check('new-password-9', $user->fresh()->password))->toBeTrue();

        // The other device is signed out; this request's token still works.
        expect($user->tokens()->count())->toBe(1);
        $this->withToken($phone)->getJson('/api/v1/me')->assertOk();
    });

    it('refuses when the current password is wrong', function (): void {
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $token = $user->createToken('phone')->plainTextToken;

        $this->withToken($token)
            ->putJson('/api/v1/password', [
                'current_password' => 'not-the-password',
                'password' => 'new-password-9',
                'password_confirmation' => 'new-password-9',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('current_password');

        expect(Hash::check('old-password', $user->fresh()->password))->toBeTrue();
    });

    it('requires a matching confirmation and eight characters', function (): void {
        $user = User::factory()->create(['password' => Hash::make('old-password')]);
        $token = $user->createToken('phone')->plainTextToken;

        $this->withToken($token)
            ->putJson('/api/v1/password', [
                'current_password' => 'old-password',
                'password' => 'short',
                'password_confirmation' => 'different',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    });

    it('needs a session at all', function (): void {
        $this->putJson('/api/v1/password', [
            'current_password' => 'old-password',
            'password' => 'new-password-9',
            'password_confirmation' => 'new-password-9',
        ])->assertStatus(401);
    });
});
