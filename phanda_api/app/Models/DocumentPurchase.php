<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A one-off purchase that unlocks a single document without a subscription.
 *
 * @property int $id
 * @property int $user_id
 * @property string $document_id
 * @property string $status
 * @property string $tx_ref
 * @property int $amount_mwk
 * @property Carbon|null $purchased_at
 * @property Carbon|null $expires_at
 */
#[Fillable([
    'user_id',
    'document_id',
    'status',
    'tx_ref',
    'amount_mwk',
    'purchased_at',
    'expires_at',
    'provider_data',
])]
final class DocumentPurchase extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount_mwk' => 'integer',
            'purchased_at' => 'datetime',
            'expires_at' => 'datetime',
            'provider_data' => 'array',
        ];
    }

    /**
     * @return BelongsTo<Document, $this>
     */
    public function document(): BelongsTo
    {
        return $this->belongsTo(Document::class);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isUsable(): bool
    {
        return $this->status === 'paid'
            && ($this->expires_at === null || $this->expires_at->isFuture());
    }
}
