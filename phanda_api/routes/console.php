<?php

declare(strict_types=1);

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function (): void {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');
// Subscription expiry reminders, once a day at 18:00 Malawi time.
Schedule::command('notifications:reminders')->dailyAt('18:00')->timezone('Africa/Blantyre');