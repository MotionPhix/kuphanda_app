<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * When the learner agreed to receive sign-in codes on WhatsApp.
 *
 * Meta's Business Messaging Policy requires opt-in for business-initiated
 * messages, and an authentication code counts. "They asked for the code" is the
 * consent, but a claim is not evidence: this column is the record. It is set the
 * moment a code proves the number — never on a number that was merely typed.
 *
 * Kept separate from `phone_verified_at` even though they are written together
 * today: verification is a fact about the number, consent is a fact about the
 * person, and a future change (re-consent after a policy update, a learner who
 * withdraws) must be able to move one without rewriting the other.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->timestamp('whatsapp_opt_in_at')->nullable()->after('phone_verified_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('whatsapp_opt_in_at');
        });
    }
};
