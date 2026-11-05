<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One row per code that was actually sent.
 *
 * The code itself is never stored: `code_hash` is a password hash, so a copy of
 * this table cannot be used to sign in as anyone. `attempts` is here because a
 * six-digit code is only worth 10^6 guesses — without a per-challenge cap the
 * code is a formality, not a second factor.
 *
 * `user_id` is null for a sign-up: the account does not exist until the code
 * comes back. That is deliberate — an unverified phone must not reserve an
 * account, or anyone could block a number by typing it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('otp_challenges', function (Blueprint $table): void {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->nullable()->constrained()->cascadeOnDelete();
            $table->string('phone_e164', 20)->index();
            // login | signup | link
            $table->string('purpose', 16);
            $table->string('code_hash');
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('expires_at')->index();
            $table->timestamp('consumed_at')->nullable();
            $table->string('ip', 45)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('otp_challenges');
    }
};
