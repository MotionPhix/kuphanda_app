<?php

declare(strict_types=1);

namespace App\Contracts;

interface PaymentGateway
{
    /**
     * @param  array<string, mixed>  $data
     * @return array{success: bool, tx_ref?: string, checkout_url?: string|null, message?: string, data?: array<string, mixed>}
     */
    public function initiatePayment(array $data): array;

    /**
     * @return array{verified: bool, status?: string|null, amount?: float|null, currency?: string|null, data?: array<string, mixed>, message?: string}
     */
    public function verifyTransaction(string $txRef): array;

    public function verifyWebhookSignature(string $payload, string $signature): bool;
}
