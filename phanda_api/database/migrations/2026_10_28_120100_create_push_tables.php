<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One row per installation. The FCM token is unique across the table:
        // when a device signs into a different account the row is reassigned,
        // so a token can never deliver another learner's messages.
        Schema::create('device_tokens', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token', 255)->unique();
            $table->string('platform', 16)->default('android');
            $table->string('app_version', 32)->nullable();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'platform']);
        });

        // Audit trail of everything sent. Gives the app an in-app fallback when
        // a push is missed and gives staff a record of what went out.
        Schema::create('push_messages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('sent_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('audience', 32);
            $table->string('audience_value', 32)->nullable();
            $table->string('category', 32)->default('general');
            $table->string('title', 160);
            $table->text('body');
            $table->json('data')->nullable();
            $table->unsignedInteger('delivered')->default(0);
            $table->unsignedInteger('failed')->default(0);
            $table->timestamps();

            $table->index(['audience', 'created_at']);
            $table->index('category');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('push_messages');
        Schema::dropIfExists('device_tokens');
    }
};
