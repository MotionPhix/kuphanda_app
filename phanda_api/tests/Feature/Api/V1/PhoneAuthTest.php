<?php

declare(strict_types=1);

use App\Contracts\OtpSender;
use App\Models\OtpChallenge;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

/**
 * Records what would have gone to WhatsApp, so the code can be read back the way
 * a learner reads it off their phone.
 *
 * The transport itself is covered by FirebasePushSenderTest-style shape checks;
 * these tests are about the rules around the code, which is where the security
 * of the feature lives.
 */
final class RecordingOtpSender implements OtpSender
{
    /** @var list<array{to: string, code: string}> */
    public array $sent = [];

    public bool $healthy = true;

    public bool $configured = true;

    public function sendCode(string $e164, string $code): bool
    {
        if (! $this->healthy) {
            return false;
        }

        $this->sent[] = ['to' => $e164, 'code' => $code];

        return true;
    }

    public function isConfigured(): bool
    {
        return $this->configured;
    }

    public function transport(): string
    {
        return 'test_recorder';
    }
}

beforeEach(function (): void {
    $this->sender = new RecordingOtpSender();
    $this->app->instance(OtpSender::class, $this->sender);
});

function phoneUser(string $phone = '+265991234567'): User
{
    $user = User::factory()->create(['email' => 'learner@example.mw']);

    $user->forceFill(['phone_e164' => $phone, 'phone_verified_at' => now()])->save();

    return $user;
}

it('accepts the way people actually type a Malawian number', function (string $typed): void {
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => $typed, 'purpose' => 'login'])
        ->assertOk()
        ->assertJsonPath('data.phone', '+265991234567');

    expect($this->sender->sent[0]['to'])->toBe('+265991234567');
})->with([
    'local' => '0991234567',
    'spaced' => '099 123 4567',
    'country code' => '265991234567',
    'e164' => '+265991234567',
]);

it('says so when no account uses the number, and sends nothing', function (): void {
    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0881234567', 'purpose' => 'login'])
        ->assertOk()
        ->assertJsonPath('data.exists', false);

    expect($this->sender->sent)->toBeEmpty()
        ->and(OtpChallenge::query()->count())->toBe(0);
});

it('rejects a landline or a malformed number before sending', function (string $bad): void {
    $this->postJson('/api/v1/auth/otp/start', ['phone' => $bad, 'purpose' => 'login'])
        ->assertStatus(422)
        ->assertJsonPath('errors.code', 'PHONE_INVALID');

    expect($this->sender->sent)->toBeEmpty();
})->with(['021234567', '123', 'not a number']);

it('signs in a verified number and never returns the code', function (): void {
    $user = phoneUser();

    $start = $this->postJson('/api/v1/auth/otp/start', [
        'phone' => '+265991234567',
        'purpose' => 'login',
    ])->assertOk();

    $code = $this->sender->sent[0]['code'];

    expect($start->json('data.challenge'))->not->toBeEmpty()
        ->and($start->json('data.code'))->toBeNull()
        ->and(json_encode($start->json()))->not->toContain($code);

    $verified = $this->postJson('/api/v1/auth/otp/verify', [
        'challenge' => $start->json('data.challenge'),
        'code' => $code,
    ])
        ->assertOk()
        ->assertJsonPath('data.user.id', $user->id);

    // The token from the code works on a protected route: this is a real
    // session, not a one-off check.
    $this->withHeader('Authorization', 'Bearer '.$verified->json('data.token'))
        ->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonPath('data.id', $user->id);
});

it('works one time only', function (): void {
    phoneUser();

    $start = $this->postJson('/api/v1/auth/otp/start', [
        'phone' => '+265991234567',
        'purpose' => 'login',
    ])->assertOk();

    $payload = [
        'challenge' => $start->json('data.challenge'),
        'code' => $this->sender->sent[0]['code'],
    ];

    $this->postJson('/api/v1/auth/otp/verify', $payload)->assertOk();
    $this->postJson('/api/v1/auth/otp/verify', $payload)
        ->assertStatus(422)
        ->assertJsonPath('errors.code', 'OTP_INVALID');
});

it('retires the code after five wrong guesses', function (): void {
    phoneUser();

    $start = $this->postJson('/api/v1/auth/otp/start', [
        'phone' => '+265991234567',
        'purpose' => 'login',
    ])->assertOk();

    $challenge = $start->json('data.challenge');

    for ($i = 0; $i < 4; $i++) {
        $this->postJson('/api/v1/auth/otp/verify', ['challenge' => $challenge, 'code' => '000000'])
            ->assertStatus(422)
            ->assertJsonPath('errors.code', 'OTP_INVALID');
    }

    $this->postJson('/api/v1/auth/otp/verify', ['challenge' => $challenge, 'code' => '000000'])
        ->assertStatus(429)
        ->assertJsonPath('errors.code', 'OTP_ATTEMPTS_EXCEEDED');

    // Even the right code is no longer accepted.
    $this->postJson('/api/v1/auth/otp/verify', [
        'challenge' => $challenge,
        'code' => $this->sender->sent[0]['code'],
    ])->assertStatus(422);
});

it('refuses an expired code', function (): void {
    phoneUser();

    $start = $this->postJson('/api/v1/auth/otp/start', [
        'phone' => '+265991234567',
        'purpose' => 'login',
    ]);

    OtpChallenge::query()->update(['expires_at' => now()->subMinute()]);

    $this->postJson('/api/v1/auth/otp/verify', [
        'challenge' => $start->json('data.challenge'),
        'code' => $this->sender->sent[0]['code'],
    ])
        ->assertStatus(422)
        ->assertJsonPath('errors.code', 'OTP_EXPIRED');
});

it('refuses a second code within the cooldown', function (): void {
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'login'])
        ->assertOk();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'login'])
        ->assertStatus(429)
        ->assertJsonPath('errors.code', 'OTP_RESEND_TOO_SOON');

    expect($this->sender->sent)->toHaveCount(1);
});

it('creates an account from a phone, with no email and a verified number', function (): void {
    $start = $this->postJson('/api/v1/auth/otp/start', [
        'phone' => '0995551234',
        'purpose' => 'signup',
    ])->assertOk();

    $response = $this->postJson('/api/v1/auth/otp/verify', [
        'challenge' => $start->json('data.challenge'),
        'code' => $this->sender->sent[0]['code'],
        'name' => 'Chisomo Banda',
    ])->assertStatus(201);

    $token = $response->json('data.token');

    expect($response->json('data.user.phone'))->toBe('+265995551234')
        ->and($response->json('data.user.phone_verified'))->toBeTrue()
        ->and($response->json('data.user.email'))->toBeNull()
        // The consent record Meta's policy expects, written at the moment the
        // code proved the number and not a second before.
        ->and($response->json('data.user.whatsapp_opt_in'))->toBeTrue()
        ->and($response->json('data.user.whatsapp_opt_in_at'))->not->toBeNull();

    $this->withHeader('Authorization', 'Bearer '.$token)
        ->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonPath('data.name', 'Chisomo Banda');
});

it('will not create a second account for a number that already has one', function (): void {
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'signup'])
        ->assertStatus(409)
        ->assertJsonPath('errors.code', 'PHONE_TAKEN');
});

it('links a number to the signed-in account, and only that account', function (): void {
    $user = User::factory()->create(['email' => 'teacher@example.mw']);
    $token = $user->createToken('auth-token')->plainTextToken;

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'link'])
        ->assertStatus(401);

    $start = $this->withHeader('Authorization', 'Bearer '.$token)
        ->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'link'])
        ->assertOk();

    $this->withHeader('Authorization', 'Bearer '.$token)
        ->postJson('/api/v1/auth/otp/verify', [
            'challenge' => $start->json('data.challenge'),
            'code' => $this->sender->sent[0]['code'],
        ])
        ->assertOk()
        ->assertJsonPath('data.phone_verified', true);

    expect($user->fresh()->phone_e164)->toBe('+265991234567');
});

it('answers 503 rather than pretending, when WhatsApp is not configured', function (): void {
    $this->sender->configured = false;
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'login'])
        ->assertStatus(503)
        ->assertJsonPath('errors.code', 'OTP_CHANNEL_UNAVAILABLE');

    expect($this->sender->sent)->toBeEmpty();
});

it('does not leave a usable challenge behind when delivery fails', function (): void {
    $this->sender->healthy = false;
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'login'])
        ->assertStatus(503)
        ->assertJsonPath('errors.code', 'OTP_NOT_DELIVERED');

    expect(OtpChallenge::query()->whereNull('consumed_at')->count())->toBe(0);
});

it('records no consent for a number that was only typed', function (): void {
    $user = User::factory()->create(['email' => 'quiet@example.mw']);
    $token = $user->createToken('auth-token')->plainTextToken;

    // A code is requested against the account, then abandoned. Nothing about the
    // number may stick: no number, no verified mark, no consent.
    $this->withHeader('Authorization', 'Bearer '.$token)
        ->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'link'])
        ->assertOk();

    expect($user->fresh()->phone_e164)->toBeNull()
        ->and($user->fresh()->phone_verified_at)->toBeNull()
        ->and($user->fresh()->whatsapp_opt_in_at)->toBeNull();
});

it('stores the code as a hash, not as digits', function (): void {
    phoneUser();

    $this->postJson('/api/v1/auth/otp/start', ['phone' => '0991234567', 'purpose' => 'login']);

    $challenge = OtpChallenge::query()->firstOrFail();

    expect($challenge->code_hash)->not->toBe($this->sender->sent[0]['code'])
        ->and(Hash::check($this->sender->sent[0]['code'], $challenge->code_hash))->toBeTrue();
});
