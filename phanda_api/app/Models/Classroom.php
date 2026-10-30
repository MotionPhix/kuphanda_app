<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * A class a teacher runs. Learners join with the six-character code rather than
 * an email address, because most schools here hand out a code before they hand
 * out an inbox.
 */
final class Classroom extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'code',
        'name',
        'form',
        'subject_id',
        'teacher_id',
    ];

    protected static function booted(): void
    {
        static::creating(function (Classroom $classroom): void {
            $classroom->id ??= 'cls_'.Str::lower(Str::random(12));
            $classroom->code ??= self::freshCode();
        });
    }

    /**
     * A code somebody can read from a blackboard: no O/0, I/1 or S/5.
     */
    public static function freshCode(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRTUVWXYZ2346789';

        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
            }
        } while (self::query()->where('code', $code)->exists());

        return $code;
    }

    public function teacher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'teacher_id');
    }

    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'classroom_members', 'classroom_id', 'user_id')
            ->withPivot('joined_at');
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(ClassroomAssignment::class)->orderBy('due_date')->orderBy('id');
    }

    public function hasMember(User $user): bool
    {
        return $this->members()->whereKey($user->getKey())->exists();
    }

    public function isRunBy(User $user): bool
    {
        return (int) $this->teacher_id === (int) $user->getKey();
    }
}
