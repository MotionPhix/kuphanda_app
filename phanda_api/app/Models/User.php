<?php

declare(strict_types=1);

namespace App\Models;

use App\Enums\LibraryPlan;
use App\Notifications\ResetPasswordNotification;
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
 * @property string|null $email
 * @property string|null $phone_e164
 * @property Carbon|null $phone_verified_at
 * @property string $role
 * @property int|null $form
 * @property Carbon|null $profile_completed_at
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
    'phone_e164',
    'password',
    'plan',
    'role',
    'form',
    'google_id',
    'avatar_url',
    'is_staff',
    'profile_completed_at',
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
            // Null unless a WhatsApp code proved the number. Nothing else may
            // treat `phone_e164` as an identity.
            'phone_verified_at' => 'datetime',
            'password' => 'hashed',
            'plan' => LibraryPlan::class,
            'is_staff' => 'boolean',
            'form' => 'integer',
            'profile_completed_at' => 'datetime',
        ];
    }

    /**
     * @return HasMany<OfflineDocument, $this>
     */
    public function offlineDocuments(): HasMany
    {
        return $this->hasMany(OfflineDocument::class);
    }

    /**
     * The stock notification points at a route this API does not serve with a
     * GET, so the link in the email went nowhere. Ours opens the page that
     * collects the new password.
     */
    public function sendPasswordResetNotification($token): void
    {
        $this->notify(new ResetPasswordNotification($token));
    }
}


