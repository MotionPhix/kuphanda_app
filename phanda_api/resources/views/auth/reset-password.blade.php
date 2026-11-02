<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $done ? 'Password changed' : 'Choose a new password' }} · Kuphanda</title>
    <style>
        :root { color-scheme: light; }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            background: #f6f3ea;
            color: #1d2a21;
            font: 16px/1.5 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }
        .card {
            width: 100%;
            max-width: 420px;
            background: #fff;
            border-radius: 18px;
            padding: 28px 24px;
            box-shadow: 0 10px 30px rgba(22, 51, 35, .08);
        }
        .mark {
            width: 44px; height: 44px; border-radius: 12px;
            background: #12492f; color: #fff; font-weight: 700;
            display: flex; align-items: center; justify-content: center;
            margin-bottom: 18px;
        }
        h1 { font-size: 22px; margin: 0 0 6px; }
        p.lead { margin: 0 0 20px; color: #55655c; font-size: 15px; }
        label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; color: #3b4a41; }
        input {
            width: 100%; padding: 13px 14px; font-size: 16px;
            border: 1px solid #cfd8d2; border-radius: 12px; background: #fbfdfb;
        }
        input:focus { outline: 2px solid #12492f; outline-offset: 1px; border-color: #12492f; }
        .field { margin-bottom: 14px; }
        button {
            width: 100%; padding: 14px 16px; margin-top: 8px;
            font-size: 16px; font-weight: 600; color: #fff;
            background: #12492f; border: 0; border-radius: 12px;
            cursor: pointer;
        }
        button:active { background: #0d3a25; }
        .notice, .error {
            border-radius: 12px; padding: 12px 14px; font-size: 14px; margin-bottom: 18px;
        }
        .notice { background: #e8f3ec; color: #12492f; }
        .error { background: #fdecec; color: #8a1f1f; }
        .fine { margin-top: 18px; font-size: 13px; color: #6b7b72; }
    </style>
</head>
<body>
<main class="card">
    <div class="mark">K</div>

    @if ($done)
        <h1>Password changed</h1>
        <p class="lead">You can open Kuphanda and sign in with the new password.</p>
        <div class="notice">
            Any other phone or computer signed in to this account has been signed
            out, and this link will not work again.
        </div>
        <p class="fine">If this was not you, reset the password again and tell your school.</p>
    @elseif (! $usable)
        <h1>This link is not complete</h1>
        <p class="lead">A reset link carries its own code, and this one arrived without it.</p>
        <div class="error">
            Open the newest “Reset your Kuphanda password” email and use the button
            in it, or ask for a new link from the sign-in screen in the app.
        </div>
    @else
        <h1>Choose a new password</h1>
        <p class="lead">For {{ $email }}. Eight characters or more.</p>

        @if ($errors->any())
            <div class="error">{{ $errors->first() }}</div>
        @endif

        <form method="POST" action="{{ route('password.reset.submit') }}">
            @csrf
            <input type="hidden" name="token" value="{{ $token }}">
            <div class="field">
                <label for="email">Email</label>
                <input id="email" name="email" type="email" value="{{ old('email', $email) }}" required>
            </div>
            <div class="field">
                <label for="password">New password</label>
                <input id="password" name="password" type="password" autocomplete="new-password" required minlength="8">
            </div>
            <div class="field">
                <label for="password_confirmation">Repeat it</label>
                <input id="password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" required minlength="8">
            </div>
            <button type="submit">Change password</button>
        </form>

        <p class="fine">The link works once, and expires after 60 minutes.</p>
    @endif
</main>
</body>
</html>



