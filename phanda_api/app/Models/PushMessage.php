<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property int $id
 * @property int|null $sent_by
 * @property string $audience
 * @property string|null $audience_value
 * @property string $category
 * @property string $title
 * @property string $body
 * @property array<string, mixed>|null $data
 * @property int $delivered
 * @property int $failed
 */
final class PushMessage extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'sent_by',
        'audience',
        'audience_value',
        'category',
        'title',
        'body',
        'data',
        'delivered',
        'failed',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'data' => 'array',
            'delivered' => 'integer',
            'failed' => 'integer',
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sent_by');
    }
}
