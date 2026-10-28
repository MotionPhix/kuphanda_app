<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\LibraryPlan;
use Database\Factories\UserFactory;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

/**
 * @property int $id
 * @property string $name
 * @property string|null $school
 * @property LibraryPlan $plan
 * @property string $email
 * @property Carbon|null $email_verified_at
 * @property string $password
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable([
    'name',
    'first_name',
    'last_name',
    'school',
    'email',
    'password',
    'plan',
    'role',
    'form',
    'google_id',
    'avatar_url',
    'is_staff',
])]
#[Hidden([
    'password',
    'remember_token',
])]
final class User extends Authenticatable implements MustVerifyEmail
{
    use HasApiTokens;

    /** @use HasFactory<UserFactory> */
    use HasFactory;

    use Notifiable;

    /**
     * @var array<string, mixed>
     */
    protected $attributes = [
        'plan' => 'free',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'plan' => LibraryPlan::class,
            'is_staff' => 'boolean',
            'form' => 'integer',
        ];
    }

    /**
     * @return HasMany<OfflineDocument, $this>
     */
    public function offlineDocuments(): HasMany
    {
        return $this->hasMany(OfflineDocument::class);
    }
}
