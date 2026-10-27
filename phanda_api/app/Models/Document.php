<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\AccessTier;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

/**
 * A document record owned by the library. The file itself lives in
 * document_versions; a document without a version is metadata only.
 *
 * @property string $id
 * @property string $subject_id
 * @property string $title
 * @property int $form
 * @property string $kind
 * @property string|null $description
 * @property int $pages
 * @property int|null $year
 * @property int|null $paper_number
 * @property string|null $session
 * @property int|null $total_marks
 * @property int|null $duration_minutes
 * @property AccessTier $access_tier
 * @property string $author
 * @property string|null $publisher
 * @property string $language
 * @property array<int, string>|null $tags
 * @property string|null $guide_id
 * @property bool $featured
 * @property bool $is_published
 * @property int $latest_version
 * @property Carbon|null $content_updated_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable([
    'id',
    'subject_id',
    'title',
    'form',
    'kind',
    'description',
    'pages',
    'year',
    'paper_number',
    'session',
    'total_marks',
    'duration_minutes',
    'access_tier',
    'price_mwk',
    'author',
    'publisher',
    'language',
    'tags',
    'guide_id',
    'featured',
    'is_published',
    'latest_version',
    'content_updated_at',
])]
final class Document extends Model
{
    use HasFactory;

    public $incrementing = false;

    protected $keyType = 'string';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'form' => 'integer',
            'pages' => 'integer',
            'year' => 'integer',
            'paper_number' => 'integer',
            'total_marks' => 'integer',
            'duration_minutes' => 'integer',
            'access_tier' => AccessTier::class,
            'price_mwk' => 'integer',
            'tags' => 'array',
            'featured' => 'boolean',
            'is_published' => 'boolean',
            'latest_version' => 'integer',
            'content_updated_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Subject, $this>
     */
    public function subject(): BelongsTo
    {
        return $this->belongsTo(Subject::class);
    }

    /**
     * @return HasMany<DocumentVersion, $this>
     */
    public function versions(): HasMany
    {
        return $this->hasMany(DocumentVersion::class);
    }

    /**
     * @return HasOne<DocumentVersion, $this>
     */
    public function currentVersion(): HasOne
    {
        return $this->hasOne(DocumentVersion::class)->latestOfMany('version');
    }

    /**
     * @return HasMany<OfflineDocument, $this>
     */
    public function offlineMarks(): HasMany
    {
        return $this->hasMany(OfflineDocument::class);
    }

    /**
     * @param  Builder<Document>  $query
     * @return Builder<Document>
     */
    public function scopePublished(Builder $query): Builder
    {
        return $query->where('is_published', true);
    }

    public function isAvailable(User $user): bool
    {
        return $this->is_published
            && $this->latest_version > 0
            && $user->plan->covers($this->access_tier);
    }
}
