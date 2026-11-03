<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Onboarding is a one-time interview: who you are, whether you teach or study,
 * and which form you sit in. The app used to guess it was done from "does this
 * account have a school?", so a learner who never filled that optional field was
 * asked the whole thing again on every new phone. This column is the answer the
 * server can give instead.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->timestamp('profile_completed_at')->nullable()->after('form');
        });

        // Existing accounts that already carry the answers are onboarded; the
        // next sign-in must not interview them again.
        DB::table('users')
            ->whereNotNull('first_name')
            ->where('first_name', '!=', '')
            ->whereNotNull('last_name')
            ->where('last_name', '!=', '')
            ->whereIn('role', ['student', 'teacher'])
            ->update(['profile_completed_at' => DB::raw('COALESCE(updated_at, created_at)')]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('profile_completed_at');
        });
    }
};
