<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

describe('Registration', function (): void {
    it('registers a new user successfully', function (): void {
        $response = $this->postJson('/api/v1/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'user' => ['id', 'name', 'email'],
                    'token',
                ],
            ])
            ->assertJson([
                'success' => true,
                'message' => 'Account created. You can start reading now.',
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'test@example.com',
        ]);
    });

    it('still creates the account when the verification mail cannot be sent', function (): void {
        // Shared hosts lose SMTP often, and this is what answered 500 on the
        // live server: the row was written, then mail threw, and the learner was
        // left with an account they could not sign in to.
        $this->app->bind(\App\Services\VerificationMailer::class, fn () => new class extends \App\Services\VerificationMailer
        {
            public function send(User $user): void
            {
                throw new RuntimeException('SMTP connection refused');
            }
        });

        $response = $this->postJson('/api/v1/register', [
            'name' => 'Mail Down',
            'email' => 'maildown@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201)->assertJsonPath('success', true);

        $this->assertDatabaseHas('users', ['email' => 'maildown@example.com']);

        // The token still works: a missing email does not block reading.
        $token = $response->json('data.token');
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'maildown@example.com');
    });

    it('fails registration with invalid data', function (): void {
        $response = $this->postJson('/api/v1/register', [
            'name' => '',
            'email' => 'invalid-email',
            'password' => 'short',
        ]);

        $response->assertStatus(422);
    });

    it('fails registration with duplicate email', function (): void {
        User::factory()->create(['email' => 'existing@example.com']);

        $response = $this->postJson('/api/v1/register', [
            'name' => 'Test User',
            'email' => 'existing@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(422);
    });
});

describe('Login', function (): void {
    it('logs in with valid credentials', function (): void {
        $user = User::factory()->create([
            'password' => bcrypt('password123'),
        ]);

        $response = $this->postJson('/api/v1/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'user' => ['id', 'name', 'email'],
                    'token',
                ],
            ])
            ->assertJson([
                'success' => true,
                'message' => 'Login successful',
            ]);
    });

    it('fails login with invalid credentials', function (): void {
        $user = User::factory()->create([
            'password' => bcrypt('password123'),
        ]);

        $response = $this->postJson('/api/v1/login', [
            'email' => $user->email,
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid credentials',
            ]);
    });

    it('fails login with non-existent user', function (): void {
        $response = $this->postJson('/api/v1/login', [
            'email' => 'nonexistent@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(401);
    });
});

describe('Logout', function (): void {
    it('logs out authenticated user', function (): void {
        $user = User::factory()->create();
        $token = $user->createToken('test-token')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/logout');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Logged out successfully',
            ]);
    });

    it('fails logout without authentication', function (): void {
        $response = $this->postJson('/api/v1/logout');

        $response->assertStatus(401);
    });
});

describe('Me', function (): void {
    it('returns authenticated user data', function (): void {
        $user = User::factory()->create();
        $token = $user->createToken('test-token')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/me');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => ['id', 'name', 'email'],
            ])
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $user->id,
                    'email' => $user->email,
                ],
            ]);
    });

    it('fails without authentication', function (): void {
        $response = $this->getJson('/api/v1/me');

        $response->assertStatus(401);
    });

    it('answers 401 even when the client forgets the JSON accept header', function (): void {
        // Without an Accept header Laravel redirects a guest to route('login'),
        // which does not exist in an API-only app — so this used to be a 500
        // that pointed at the wrong problem entirely.
        $response = $this->get('/api/v1/me');

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'message' => 'Unauthenticated.',
            ]);
    });
});

describe('Onboarding state', function (): void {
    it('reports a newly registered account as not onboarded', function (): void {
        $this->postJson('/api/v1/register', [
            'name' => 'New Learner',
            'email' => 'new@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])
            ->assertStatus(201)
            ->assertJsonPath('data.user.profile_completed', false);
    });

    it('returns a returning teacher their role and completion on login', function (): void {
        User::factory()->create([
            'name' => 'Grace Mwale',
            'first_name' => 'Grace',
            'last_name' => 'Mwale',
            'email' => 'grace@example.com',
            'password' => 'password123',
            'role' => 'teacher',
            'form' => null,
            'profile_completed_at' => now(),
        ]);

        $this->postJson('/api/v1/login', [
            'email' => 'grace@example.com',
            'password' => 'password123',
        ])
            ->assertOk()
            ->assertJsonPath('data.user.role', 'teacher')
            ->assertJsonPath('data.user.form', null)
            ->assertJsonPath('data.user.profile_completed', true);
    });
});
