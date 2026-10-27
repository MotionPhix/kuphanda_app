<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Entitlement tier for a document, ranked exactly as the client ranks it.
 */
enum AccessTier: string
{
    case Free = 'free';
    case Daily = 'daily';
    case Weekly = 'weekly';
    case Monthly = 'monthly';
    case School = 'school';

    public function rank(): int
    {
        return match ($this) {
            self::Free => 0,
            self::Daily => 1,
            self::Weekly => 2,
            self::Monthly => 3,
            self::School => 4,
        };
    }

    public function label(): string
    {
        return match ($this) {
            self::Free => 'Free',
            self::Daily => 'Day pass',
            self::Weekly => 'Weekly pass',
            self::Monthly => 'Monthly pass',
            self::School => 'School licence',
        };
    }
}
