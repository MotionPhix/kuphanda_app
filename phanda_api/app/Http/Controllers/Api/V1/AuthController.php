<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\ChangePasswordRequest;
use App\Http\Requests\Api\V1\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\GoogleSignInRequest;
use App\Http\Requests\Api\V1\UpdateProfileRequest;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\RegisterRequest;
use App\Http\Requests\Api\V1\ResendVerificationRequest;
use App\Http\Requests\Api\V1\ResetPasswordRequest;
use App\Http\Requests\Api\V1\VerifyEmailRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\GoogleTokenVerifier;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use RuntimeException;

final class AuthController extends ApiController
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::query()->create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'plan' => 'free',
        ]);

        $user->sendEmailVerificationNotification();

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->created([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'User registered successfully. Please check your email to verify your account.');
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::query()->where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return $this->unauthorized('Invalid credentials');
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->success([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'Login successful');
    }

    /**
     * Signs in (or links) a Google account.
     *
     * A verified Google email may match an existing password account: the
     * Google identity is then linked to that user rather than creating a
     * duplicate. Existing names are never overwritten — only blank profile
     * fields are filled from Google.
     */
    public function google(GoogleSignInRequest $request, GoogleTokenVerifier $verifier): JsonResponse
    {
        try {
            $profile = $verifier->verify((string) $request->input('id_token'));
        } catch (RuntimeException $exception) {
            return $this->error($exception->getMessage(), $exception->getCode() ?: 401);
        }

        $current = Auth::guard('sanctum')->user();
        $linked = User::query()->where('google_id', $profile['sub'])->first();

        if ($current !== null && $linked !== null && $linked->id !== $current->id) {
            return $this->error('This Google account is already linked to another user.', 409);
        }

        $user = $current
            ?? $linked
            ?? User::query()->where('email', $profile['email'])->first();

        if ($user === null) {
            $user = User::query()->create([
                'name' => $profile['name'] !== '' ? $profile['name'] : Str::before($profile['email'], '@'),
                'first_name' => $profile['given_name'] !== '' ? $profile['given_name'] : null,
                'last_name' => $profile['family_name'] !== '' ? $profile['family_name'] : null,
                'email' => $profile['email'],
                'password' => Hash::make(Str::random(40)),
                'plan' => 'free',
                'google_id' => $profile['sub'],
                'avatar_url' => $profile['picture'],
            ]);
            $user->forceFill(['email_verified_at' => now()])->save();
        } else {
            $user->google_id ??= $profile['sub'];
            $user->avatar_url ??= $profile['picture'];

            if (blank($user->first_name) && $profile['given_name'] !== '') {
                $user->first_name = $profile['given_name'];
            }

            if (blank($user->last_name) && $profile['family_name'] !== '') {
                $user->last_name = $profile['family_name'];
            }

            if (blank($user->name) && $profile['name'] !== '') {
                $user->name = $profile['name'];
            }

            if ($user->email_verified_at === null) {
                $user->email_verified_at = now();
            }

            $user->save();
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->success([
            'user' => new UserResource($user->fresh()),
            'token' => $token,
        ], $current !== null ? 'Google account linked' : 'Signed in with Google');
    }

    public function logout(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $user->currentAccessToken()->delete();

        return $this->success(message: 'Logged out successfully');
    }

    /**
     * Updates the confirmed profile. Names are stored as first/last and the
     * display name is rebuilt from them so the two never drift apart.
     */
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = $request->validated();

        $first = array_key_exists('first_name', $data)
            ? trim((string) $data['first_name'])
            : (string) $user->first_name;
        $last = array_key_exists('last_name', $data)
            ? trim((string) $data['last_name'])
            : (string) $user->last_name;

        if (array_key_exists('first_name', $data) || array_key_exists('last_name', $data)) {
            $user->first_name = $first;
            $user->last_name = $last;
            $user->name = trim($first.' '.$last);
        } elseif (array_key_exists('name', $data)) {
            $user->name = trim((string) $data['name']);
        }

        if (array_key_exists('school', $data)) {
            $user->school = $data['school'] === null ? null : trim((string) $data['school']);
        }

        // Audience fields: they decide which class and role notifications this
        // account receives. A learner cannot promote themselves to staff here;
        // `role` only distinguishes student from teacher.
        if (array_key_exists('role', $data)) {
            $user->role = (string) $data['role'];
        }

        if (array_key_exists('form', $data)) {
            $user->form = $data['form'] === null ? null : (int) $data['form'];
        }

        $user->save();

        return $this->success(new UserResource($user->fresh()), 'Profile updated.');
    }

    public function me(Request $request): JsonResponse
    {
        return $this->success(new UserResource($request->user()));
    }

    public function verifyEmail(VerifyEmailRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if ($user->hasVerifiedEmail()) {
            return $this->success(message: 'Email already verified');
        }

        if ($user->markEmailAsVerified()) {
            event(new Verified($user));
        }

        return $this->success(message: 'Email verified successfully');
    }

    public function resendVerificationEmail(ResendVerificationRequest $request): JsonResponse
    {
        $user = User::query()->where('email', $request->email)->first();

        if (! $user) {
            return $this->notFound('User not found');
        }

        if ($user->hasVerifiedEmail()) {
            return $this->error('Email already verified', 400);
        }

        $user->sendEmailVerificationNotification();

        return $this->success(message: 'Verification email sent successfully');
    }

    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $status = Password::sendResetLink(
            $request->only('email')
        );

        if ($status === Password::RESET_LINK_SENT) {
            return $this->success(message: 'Password reset link sent to your email');
        }

        return $this->error('Unable to send reset link', 500);
    }

    /**
     * Changing the password from a signed-in phone, without the email round
     * trip. Every other device is signed out; this one keeps working, because
     * the person changing it is holding it.
     */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $user->forceFill(['password' => Hash::make($request->string('password')->toString())])->save();

        $current = $user->currentAccessToken();
        $user->tokens()
            ->when($current !== null, fn ($query) => $query->where('id', '!=', $current->getKey()))
            ->delete();

        return $this->success(message: 'Password changed. Other devices were signed out.');
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password): void {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();

                $user->tokens()->delete();

                event(new PasswordReset($user));
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return $this->success(message: 'Password reset successfully');
        }

        return $this->error(
            match ($status) {
                Password::INVALID_TOKEN => 'Invalid or expired reset token',
                Password::INVALID_USER => 'User not found',
                default => 'Unable to reset password',
            },
            400
        );
    }
}

