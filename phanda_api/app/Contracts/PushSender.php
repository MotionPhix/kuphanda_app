<?php

declare(strict_types=1);

namespace App\Contracts;

/**
 * Transport for push notifications. Implementations must never throw for an
 * ordinary delivery failure: a missed notification must not break a payment,
 * a sync or a command.
 */
interface PushSender
{
    /**
     * @param  array{title: string, body: string, data?: array<string, mixed>}  $payload
     */
    public function sendToToken(string $token, array $payload): bool;

    /**
     * @param  array{title: string, body: string, data?: array<string, mixed>}  $payload
     */
    public function sendToTopic(string $topic, array $payload): bool;

    /** Whether real credentials are configured. */
    public function isConfigured(): bool;
}
