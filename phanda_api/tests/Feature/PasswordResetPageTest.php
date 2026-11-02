<?php

declare(strict_types=1);

use App\Models\User;
use App\Notifications\ResetPasswordNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;

uses(RefreshDatabase::class);

describe('The reset link in the email', function (): void {
    it('points at a page the phone can open, not the JSON endpoint', function (): void {
        Notification::fake();
        $user = User::factory()->create();

        $this->postJson('/api/v1/forgot-password', ['email' => $user->email])
            ->assertStatus(200);

        Notification::assertSentTo($user, ResetPasswordNotification::class, function (ResetPasswordNotification $notification) use ($user): bool {
            $mail = $notification->toMail($user);
            $action = $mail->actionUrl;

            return str_contains($action, '/reset-password?')
                && str_contains($action, 'token=')
                && str_contains($action, urlencode($user->email));
        });
    });

    it('shows the form the link opens', function (): void {
        $user = User::factory()->create();
        $token = Password::createToken($user);

        $this->get('/reset-password?token='.$token.'&email='.urlencode($user->email))
            ->assertOk()
            ->assertSee('Choose a new password')
            ->assertSee($user->email);
    });

    it('changes the password and keeps the learner signed out everywhere', function (): void {
        $user = User::factory()->create();
        $user->createToken('phone');
        $token = Password::createToken($user);

        $this->post('/reset-password', [
            'token' => $token,
            'email' => $user->email,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ])->assertRedirect('/reset-password/done');

        expect(Hash::check('brand-new-pass', $user->fresh()->password))->toBeTrue();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    });

    it('shows only a confirmation once the password is changed', function (): void {
        $user = User::factory()->create();
        $token = Password::createToken($user);

        $this->post('/reset-password', [
            'token' => $token,
            'email' => $user->email,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ]);

        // The form is single use: leaving it on screen invites a second, failing
        // submission of the same token.
        $this->get('/reset-password/done')
            ->assertOk()
            ->assertSee('Password changed')
            ->assertDontSee('Change password')
            ->assertDontSee('name="password"', false);
    });

    it('explains a link that arrived without its code', function (): void {
        $this->get('/reset-password')
            ->assertOk()
            ->assertSee('This link is not complete')
            ->assertDontSee('Change password');
    });

    it('says so when the link is stale', function (): void {
        $user = User::factory()->create();

        $this->from('/reset-password')->post('/reset-password', [
            'token' => 'not-a-real-token',
            'email' => $user->email,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ])->assertRedirect('/reset-password')
            ->assertSessionHasErrors('email');
    });
});
