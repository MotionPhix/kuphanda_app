<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\AccessTier;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A purchasable subscription. The tier is what the content gate compares;
 * duration and price are billing details.
 */
#[Fillable([
    'slug',
    'name',
    'access_tier',
    'price_mwk',
    'duration_days',
    'description',
    'is_active',
    'sort_order',
])]
final class Plan extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'access_tier' => AccessTier::class,
            'price_mwk' => 'integer',
            'duration_days' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    /**
     * @return HasMany<Subscription, $this>
     */
    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }
}
