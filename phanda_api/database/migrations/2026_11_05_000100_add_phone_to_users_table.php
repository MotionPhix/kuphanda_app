<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phone as a second identity.
 *
 * The account keeps its email — schools issue one, and password reset still
 * uses it — but a learner can now sign in with a number instead. The column is
 * nullable and unique: nullable because an account created from a phone has no
 * address yet, unique because a number must never open two accounts.
 *
 * `phone_verified_at` is the column that matters. A number typed into a form is
 * a claim; only the WhatsApp code proves it, and only a proven number may be
 * used to sign in. Anything that treats an unverified number as identity is an
 * account-takeover bug waiting for a typo.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('phone_e164', 20)->nullable()->unique()->after('email');
            $table->timestamp('phone_verified_at')->nullable()->after('email_verified_at');
        });

        // An account created from a phone number has no address to collect.
        Schema::table('users', function (Blueprint $table): void {
            $table->string('email')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['phone_e164']);
            $table->dropColumn(['phone_e164', 'phone_verified_at']);
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->string('email')->nullable(false)->change();
        });
    }
};
