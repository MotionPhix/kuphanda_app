<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

final class PlanSeeder extends Seeder
{
    public function run(): void
    {
        $plans = [
            [
                'slug' => 'day',
                'name' => 'Day pass',
                'access_tier' => 'daily',
                'price_mwk' => 500,
                'duration_days' => 1,
                'description' => 'Full catalogue for 24 hours. Good for one past paper session.',
                'sort_order' => 1,
            ],
            [
                'slug' => 'week',
                'name' => 'Weekly pass',
                'access_tier' => 'weekly',
                'price_mwk' => 1500,
                'duration_days' => 7,
                'description' => 'Full catalogue for a week, including marking schemes and premium guides.',
                'sort_order' => 2,
            ],
            [
                'slug' => 'month',
                'name' => 'Monthly pass',
                'access_tier' => 'monthly',
                'price_mwk' => 4500,
                'duration_days' => 30,
                'description' => 'A month of unlimited reading, ideal for the run-up to MSCE.',
                'sort_order' => 3,
            ],
            [
                'slug' => 'term',
                'name' => 'Term pass',
                'access_tier' => 'school',
                'price_mwk' => 12000,
                'duration_days' => 120,
                'description' => 'A full school term of access to every document in the library.',
                'sort_order' => 4,
            ],
        ];

        foreach ($plans as $plan) {
            Plan::query()->updateOrCreate(['slug' => $plan['slug']], $plan + ['is_active' => true]);
        }
    }
}
