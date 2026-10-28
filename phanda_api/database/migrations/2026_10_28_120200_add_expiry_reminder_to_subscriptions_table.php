<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscriptions', function (Blueprint $table): void {
            // Last time an expiry reminder was pushed, so a daily command can
            // run repeatedly without spamming the learner.
            $table->timestamp('expiry_reminded_at')->nullable()->after('paid_at');
        });
    }

    public function down(): void
    {
        Schema::table('subscriptions', function (Blueprint $table): void {
            $table->dropColumn('expiry_reminded_at');
        });
    }
};
