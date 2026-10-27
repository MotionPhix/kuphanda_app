<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * What the signed-in learner is entitled to. School licences are the default
 * because schools, not individual students, buy access in this market.
 */
enum LibraryPlan: string
{
    case Free = 'free';
    case School = 'school';

    public function rank(): int
    {
        return match ($this) {
            self::Free => 0,
            self::School => 4,
        };
    }

    public function covers(AccessTier $tier): bool
    {
        return $this->rank() >= $tier->rank();
    }
}
