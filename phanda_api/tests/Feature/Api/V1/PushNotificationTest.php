<?php

declare(strict_types=1);

use App\Contracts\PushSender;
use App\Models\DeviceToken;
use App\Models\PushMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    $this->sender = new class implements PushSender
    {
        /** @var list<array{topic: string|null, token: string|null, payload: array<string, mixed>}> */
        public array $sent = [];

        public bool $result = true;

        public function sendToToken(string $token, array $payload): bool
        {
            $this->sent[] = ['topic' => null, 'token' => $token, 'payload' => $payload];

            return $this->result;
        }

        public function sendToTopic(string $topic, array $payload): bool
        {
            $this->sent[] = ['topic' => $topic, 'token' => null, 'payload' => $payload];

            return $this->result;
        }

        public function isConfigured(): bool
        {
            return true;
        }
    };

    $this->app->instance(PushSender::class, $this->sender);
});

it('registers a device token for the signed-in learner', function (): void {
    $user = User::factory()->create();
    Sanctum::actingAs($user);

    $this->postJson('/api/v1/me/devices', [
        'token' => str_repeat('a', 40),
        'platform' => 'android',
        'app_version' => '1.0.0',
    ])
        ->assertOk()
        ->assertJsonPath('data.platform', 'android');

    expect(DeviceToken::query()->where('user_id', $user->id)->count())->toBe(1);
});

it('moves a device token to the account that most recently signed in', function (): void {
    $first = User::factory()->create();
    $second = User::factory()->create();

    $token = str_repeat('b', 40);

    Sanctum::actingAs($first);
    $this->postJson('/api/v1/me/devices', ['token' => $token, 'platform' => 'android'])->assertOk();

    Sanctum::actingAs($second);
    $this->postJson('/api/v1/me/devices', ['token' => $token, 'platform' => 'android'])->assertOk();

    expect(DeviceToken::query()->count())->toBe(1)
        ->and(DeviceToken::query()->first()->user_id)->toBe($second->id);
});

it('never removes a device owned by another account', function (): void {
    $owner = User::factory()->create();
    $other = User::factory()->create();

    $token = str_repeat('c', 40);
    DeviceToken::query()->create([
        'user_id' => $owner->id,
        'token' => $token,
        'platform' => 'android',
    ]);

    Sanctum::actingAs($other);
    $this->deleteJson('/api/v1/me/devices', ['token' => $token])->assertOk();

    expect(DeviceToken::query()->where('token', $token)->exists())->toBeTrue();
});

it('lets staff broadcast to a form and records the message', function (): void {
    $staff = User::factory()->create(['is_staff' => true]);
    Sanctum::actingAs($staff);

    $this->postJson('/api/v1/staff/notifications', [
        'audience' => 'form',
        'form' => 3,
        'category' => 'class',
        'title' => 'New maths paper',
        'body' => 'Paper 2 for Form 3 is now in the library.',
        'document_id' => 'sample-maths',
    ])->assertCreated();

    expect($this->sender->sent)->toHaveCount(1)
        ->and($this->sender->sent[0]['topic'])->toBe('form-3')
        ->and($this->sender->sent[0]['payload']['title'])->toBe('New maths paper');

    $message = PushMessage::query()->first();
    expect($message->audience)->toBe('form')
        ->and($message->audience_value)->toBe('3')
        ->and($message->sent_by)->toBe($staff->id);
});

it('forbids learners from broadcasting', function (): void {
    $learner = User::factory()->create(['role' => 'student']);
    Sanctum::actingAs($learner);

    $this->postJson('/api/v1/staff/notifications', [
        'audience' => 'all',
        'title' => 'Hello',
        'body' => 'Everyone',
    ])->assertForbidden();

    expect($this->sender->sent)->toBeEmpty();
});

it('limits a teacher to student audiences', function (): void {
    $teacher = User::factory()->create(['role' => 'teacher', 'is_staff' => false]);
    Sanctum::actingAs($teacher);

    $this->postJson('/api/v1/staff/notifications', [
        'audience' => 'all',
        'title' => 'School closed',
        'body' => 'No lessons today.',
    ])->assertForbidden();

    $this->postJson('/api/v1/staff/notifications', [
        'audience' => 'students',
        'title' => 'Test moved',
        'body' => 'The maths test moves to Friday.',
    ])->assertCreated();
});

it('delivers a payment confirmation to the learner devices', function (): void {
    $user = User::factory()->create();
    DeviceToken::query()->create([
        'user_id' => $user->id,
        'token' => str_repeat('d', 40),
        'platform' => 'android',
    ]);

    $push = app(App\Services\Push\PushDispatcher::class);
    $push->toUser($user, 'subscription', 'Purchase confirmed', 'You can read now.');

    expect($this->sender->sent)->toHaveCount(1)
        ->and($this->sender->sent[0]['token'])->toBe(str_repeat('d', 40))
        ->and($this->sender->sent[0]['payload']['data']['category'])->toBe('subscription');
});

it('returns only messages addressed to the learner', function (): void {
    $user = User::factory()->create(['role' => 'student', 'form' => 3]);
    Sanctum::actingAs($user);

    PushMessage::query()->create(['audience' => 'all', 'title' => 'Everyone', 'body' => 'x']);
    PushMessage::query()->create(['audience' => 'students', 'title' => 'Students', 'body' => 'x']);
    PushMessage::query()->create(['audience' => 'teachers', 'title' => 'Teachers', 'body' => 'x']);
    PushMessage::query()->create([
        'audience' => 'form', 'audience_value' => '3', 'title' => 'Form 3', 'body' => 'x',
    ]);
    PushMessage::query()->create([
        'audience' => 'form', 'audience_value' => '4', 'title' => 'Form 4', 'body' => 'x',
    ]);
    PushMessage::query()->create([
        'audience' => 'user', 'audience_value' => (string) $user->id, 'title' => 'You', 'body' => 'x',
    ]);

    $titles = collect($this->getJson('/api/v1/me/notifications')->assertOk()->json('data'))
        ->pluck('title');

    expect($titles)->toHaveCount(4)
        ->and($titles)->not->toContain('Teachers')
        ->and($titles)->not->toContain('Form 4');
});
