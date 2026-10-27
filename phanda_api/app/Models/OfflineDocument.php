<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;

/**
 * A learner's explicit "keep this for offline reading" mark.
 *
 * Soft deletes are intentional: another device needs to learn that the mark was
 * removed, and a tombstone with an updated_at is how the sync endpoint reports
 * it. Restoring a mark reuses the same row.
 *
 * @property int $id
 * @property int $user_id
 * @property string $document_id
 * @property int|null $downloaded_version
 * @property Carbon $marked_at
 * @property Carbon|null $last_synced_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property Carbon|null $deleted_at
 */
#[Fillable([
    'user_id',
    'document_id',
    'downloaded_version',
    'marked_at',
    'last_synced_at',
])]
final class OfflineDocument extends Model
{
    use SoftDeletes;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'downloaded_version' => 'integer',
            'marked_at' => 'datetime',
            'last_synced_at' => 'datetime',
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
     * @return BelongsTo<Document, $this>
     */
    public function document(): BelongsTo
    {
        return $this->belongsTo(Document::class);
    }
}
