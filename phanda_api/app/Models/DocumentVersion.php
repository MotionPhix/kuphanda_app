<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * An immutable published file for a document. A new upload always creates a new
 * row, so a client on an old version can keep reading while it refreshes.
 *
 * @property int $id
 * @property string $document_id
 * @property int $version
 * @property string $disk
 * @property string $path
 * @property string $file_name
 * @property string $mime_type
 * @property int $size_bytes
 * @property int $page_count
 * @property string $checksum
 * @property string|null $notes
 * @property Carbon $published_at
 */
#[Fillable([
    'document_id',
    'version',
    'disk',
    'path',
    'file_name',
    'mime_type',
    'size_bytes',
    'page_count',
    'checksum',
    'notes',
    'published_at',
])]
final class DocumentVersion extends Model
{
    use HasFactory;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'version' => 'integer',
            'size_bytes' => 'integer',
            'page_count' => 'integer',
            'published_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Document, $this>
     */
    public function document(): BelongsTo
    {
        return $this->belongsTo(Document::class);
    }
}
