<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Validation\Rules\Password as PasswordRule;

/**
 * The page the reset email links to.
 *
 * The app itself has no reset screen and the API is JSON-only, so the link in
 * the mail would otherwise land on a 405. This serves one plain page: the token
 * from the mail, a new password, and the same Password::reset the API uses.
 */
final class PasswordResetPageController extends Controller
{
    public function show(Request $request): View
    {
        $token = (string) $request->query('token', '');
        $email = (string) $request->query('email', '');

        return view('auth.reset-password', [
            'token' => $token,
            'email' => $email,
            // A link stripped of its token, or one somebody typed by hand, has
            // nothing to submit: say so instead of showing a form that cannot
            // work.
            'usable' => $token !== '' && $email !== '',
            'done' => false,
        ]);
    }

    /**
     * Where the form goes once the password has changed. The form is single-use,
     * so coming back to it would only invite a second, failing submission.
     */
    public function done(): View
    {
        return view('auth.reset-password', [
            'token' => '',
            'email' => '',
            'usable' => true,
            'done' => true,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'confirmed', PasswordRule::min(8)],
        ]);

        $status = Password::reset(
            $validated,
            function (User $user, string $password): void {
                $user->forceFill(['password' => Hash::make($password)])->save();

                // Anyone holding an old session loses it: a reset is also how a
                // learner takes a phone back.
                $user->tokens()->delete();
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return redirect()->route('password.reset.done');
        }

        return back()
            ->withInput($request->only('email'))
            ->withErrors([
                'email' => match ($status) {
                    Password::INVALID_TOKEN => 'That link has expired or was already used. Ask for a new one.',
                    Password::INVALID_USER => 'We could not find that account.',
                    default => 'The password could not be changed. Try again.',
                },
            ]);
    }
}

