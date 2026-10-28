<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\SubscriptionStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property int $id
 * @property int $user_id
 * @property int $plan_id
 * @property SubscriptionStatus $status
 * @property string $tx_ref
 * @property int $amount_mwk
 * @property Carbon|null $starts_at
 * @property Carbon|null $ends_at
 * @property Carbon|null $paid_at
 * @property Carbon|null $expiry_reminded_at
 * @property array<string, mixed>|null $provider_data
 */
#[Fillable([
    'user_id',
    'plan_id',
    'status',
    'tx_ref',
    'amount_mwk',
    'starts_at',
    'ends_at',
    'paid_at',
    'expiry_reminded_at',
    'provider_data',
])]
final class Subscription extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => SubscriptionStatus::class,
            'amount_mwk' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'paid_at' => 'datetime',
            'expiry_reminded_at' => 'datetime',
            'provider_data' => 'array',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return BelongsTo<Plan, $this>
     */
    public function plan(): BelongsTo
    {
        return $this->belongsTo(Plan::class);
    }

    public function isActive(): bool
    {
        return $this->status === SubscriptionStatus::Active
            && ($this->ends_at === null || $this->ends_at->isFuture());
    }
}
