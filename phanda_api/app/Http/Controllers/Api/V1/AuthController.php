<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\OtpException;
use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\ChangePasswordRequest;
use App\Http\Requests\Api\V1\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\GoogleSignInRequest;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\RegisterRequest;
use App\Http\Requests\Api\V1\ResendVerificationRequest;
use App\Http\Requests\Api\V1\ResetPasswordRequest;
use App\Http\Requests\Api\V1\StartOtpRequest;
use App\Http\Requests\Api\V1\UpdateProfileRequest;
use App\Http\Requests\Api\V1\VerifyEmailRequest;
use App\Http\Requests\Api\V1\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\GoogleTokenVerifier;
use App\Services\OtpService;
use App\Services\VerificationMailer;
use App\Support\PhoneNumber;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

final class AuthController extends ApiController
{
    public function register(RegisterRequest $request, VerificationMailer $mailer): JsonResponse
    {
        $user = User::query()->create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'plan' => 'free',
        ]);

        // The account exists from this point. If SMTP is down — common on shared
        // hosting, and the reason sign-up answered 500 on the live host — the
        // learner must still get their account rather than an error they cannot
        // act on.
        try {
            $mailer->send($user);
        } catch (Throwable $exception) {
            report($exception);
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->created([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'Account created. You can start reading now.');
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

    /**
     * Sends a six-digit code to a WhatsApp number.
     *
     * Three purposes, one endpoint, because the only real difference is which
     * account the number is allowed to belong to:
     *
     *  - login  — the number must already be on an account;
     *  - signup — it must not be, and the account is created on verification;
     *  - link   — someone signed in is adding a number to their own account.
     *
     * A number is only ever an identity once `phone_verified_at` is set. Until
     * then it is a claim, and anyone could type someone else's number.
     */
    public function startOtp(StartOtpRequest $request, OtpService $otp): JsonResponse
    {
        $phone = PhoneNumber::toE164($request->string('phone')->toString());

        if ($phone === null) {
            return $this->error(
                'That does not look like a mobile number. Use 099 123 4567.',
                422,
                ['code' => 'PHONE_INVALID']
            );
        }

        $purpose = (string) $request->input('purpose');

        /** @var User|null $current */
        $current = Auth::guard('sanctum')->user();

        if ($purpose === OtpService::PURPOSE_LINK && $current === null) {
            return $this->unauthorized('Sign in first, then add a number to this account.');
        }

        $owner = User::query()->where('phone_e164', $phone)->first();

        if ($purpose === OtpService::PURPOSE_LOGIN) {
            if ($owner === null) {
                // No code is sent and no challenge is created: there is nothing
                // to verify against, and the app offers "create an account"
                // instead of a box that can never be filled.
                return $this->success([
                    'exists' => false,
                    'phone' => $phone,
                    'channel' => 'whatsapp',
                ], 'No account uses that number yet.');
            }

            $user = $owner;
        } elseif ($purpose === OtpService::PURPOSE_SIGNUP) {
            if ($owner !== null) {
                return $this->error(
                    'That number already has an account. Sign in instead.',
                    409,
                    ['code' => 'PHONE_TAKEN']
                );
            }

            $user = null;
        } else {
            if ($owner !== null && $owner->id !== $current?->id) {
                return $this->error(
                    'That number is already on another account.',
                    409,
                    ['code' => 'PHONE_TAKEN']
                );
            }

            $user = $current;
        }

        try {
            $challenge = $otp->issue($phone, $purpose, $user, $request->ip());
        } catch (OtpException $exception) {
            return $this->error($exception->getMessage(), $exception->status(), [
                'code' => $exception->reason,
            ]);
        }

        $resendAfter = config('otp.resend_seconds', 60);

        return $this->success([
            'exists' => true,
            'challenge' => $challenge->id,
            'phone' => $phone,
            'masked' => PhoneNumber::mask($phone),
            'channel' => 'whatsapp',
            'expires_in' => max(0, (int) now()->diffInSeconds($challenge->expires_at, false)),
            // The code is never in this response, in any environment. If it were
            // here, the WhatsApp message would be theatre.
            // Sent so the sheet can count down instead of letting someone tap
            // "send again" into a refusal.
            'resend_after' => is_numeric($resendAfter) ? (int) $resendAfter : 60,
        ], 'A code is on its way to WhatsApp.');
    }

    /**
     * Checks the code and, for a sign-up, creates the account.
     *
     * Linking is allowed to happen without the password being re-entered because
     * the session token already proves the account; what the code proves is the
     * number, which is the part that was never verified.
     */
    public function verifyOtp(VerifyOtpRequest $request, OtpService $otp): JsonResponse
    {
        try {
            $challenge = $otp->verify($request->challenge, $request->code);
        } catch (OtpException $exception) {
            return $this->error($exception->getMessage(), $exception->status(), [
                'code' => $exception->reason,
            ]);
        }

        $phone = $challenge->phone_e164;

        /** @var User|null $current */
        $current = Auth::guard('sanctum')->user();

        if ($challenge->purpose === OtpService::PURPOSE_LINK) {
            if ($current === null || $challenge->user_id !== $current->id) {
                return $this->unauthorized('Sign in first, then add this number to the account.');
            }

            $taken = User::query()
                ->where('phone_e164', $phone)
                ->whereKeyNot($current->id)
                ->exists();

            if ($taken) {
                return $this->error('That number is already on another account.', 409, [
                    'code' => 'PHONE_TAKEN',
                ]);
            }

            // Consent is recorded with the number, at the moment the code came
            // back. Meta's policy wants opt-in for business-initiated messages,
            // and this timestamp is the evidence that it existed.
            $current->forceFill([
                'phone_e164' => $phone,
                'phone_verified_at' => now(),
                'whatsapp_opt_in_at' => $current->whatsapp_opt_in_at ?? now(),
            ])->save();

            $otp->consume($challenge);

            return $this->success(
                new UserResource($current->fresh()),
                'Number verified. You can sign in with it from now on.'
            );
        }

        if ($challenge->purpose === OtpService::PURPOSE_SIGNUP) {
            $name = mb_trim((string) $request->name);

            if ($name === '') {
                return $this->error(
                    'Add your name to finish creating the account.',
                    422,
                    ['code' => 'NAME_REQUIRED']
                );
            }

            if (User::query()->where('phone_e164', $phone)->exists()) {
                return $this->error('That number already has an account. Sign in instead.', 409, [
                    'code' => 'PHONE_TAKEN',
                ]);
            }

            $user = User::query()->create([
                'name' => $name,
                // No address yet. The column is nullable for exactly this case:
                // a learner whose only contact is a phone still gets an account.
                'email' => null,
                'password' => Str::random(40),
                'plan' => 'free',
                'phone_e164' => $phone,
            ]);

            $user->forceFill([
                'phone_verified_at' => now(),
                'whatsapp_opt_in_at' => now(),
            ])->save();

            $otp->consume($challenge);

            $token = $user->createToken('auth-token')->plainTextToken;

            return $this->created([
                'user' => new UserResource($user->fresh()),
                'token' => $token,
            ], 'Account created. You can start reading now.');
        }

        $user = $challenge->user_id === null
            ? null
            : User::query()->find($challenge->user_id);

        // A number can be removed from an account between sending and verifying.
        // Refusing here is what stops a stale challenge from signing in.
        if ($user === null || $user->phone_e164 !== $phone) {
            return $this->unauthorized('That number is no longer on an account. Sign in with your email.');
        }

        $otp->consume($challenge);

        $token = $user->createToken('auth-token')->plainTextToken;

        return $this->success([
            'user' => new UserResource($user),
            'token' => $token,
        ], 'Signed in with WhatsApp');
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
            ? mb_trim((string) $data['first_name'])
            : (string) $user->first_name;
        $last = array_key_exists('last_name', $data)
            ? mb_trim((string) $data['last_name'])
            : (string) $user->last_name;

        if (array_key_exists('first_name', $data) || array_key_exists('last_name', $data)) {
            $user->first_name = $first;
            $user->last_name = $last;
            $user->name = mb_trim($first.' '.$last);
        } elseif (array_key_exists('name', $data)) {
            $user->name = mb_trim((string) $data['name']);
        }

        if (array_key_exists('school', $data)) {
            $user->school = $data['school'] === null ? null : mb_trim((string) $data['school']);
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

        // Onboarding is done once the account can answer the three things the app
        // asks a new person: who you are, whether you teach or study, and — for a
        // learner — which form you sit in. Recorded here so a returning account is
        // never interviewed again on a second phone. A teacher has no form.
        if ($user->profile_completed_at === null && $this->profileIsComplete($user)) {
            $user->forceFill(['profile_completed_at' => now()])->save();
        }

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

    private function profileIsComplete(User $user): bool
    {
        $named = filled($user->first_name) && filled($user->last_name);
        $role = in_array($user->role, ['student', 'teacher'], true);
        $form = $user->role === 'teacher' || $user->form !== null;

        return $named && $role && $form;
    }
}
