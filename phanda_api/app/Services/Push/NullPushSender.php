<?php

declare(strict_types=1);

namespace App\Services\Push;

use App\Contracts\PushSender;
use Illuminate\Support\Facades\Log;

/**
 * Used when no service account is configured (local development, CI). Messages
 * are logged instead of sent so the rest of the flow stays testable.
 */
final class NullPushSender implements PushSender
{
    public function isConfigured(): bool
    {
        return false;
    }

    public function sendToToken(string $token, array $payload): bool
    {
        Log::info('Push (not configured)', [
            'to' => 'token',
            'title' => $payload['title'],
        ]);

        return false;
    }

    public function sendToTopic(string $topic, array $payload): bool
    {
        Log::info('Push (not configured)', [
            'to' => $topic,
            'title' => $payload['title'],
        ]);

        return false;
    }
}
