<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table): void {
            $table->id();
            $table->string('slug', 32)->unique();
            $table->string('name');
            $table->string('access_tier', 16);
            $table->unsignedInteger('price_mwk');
            $table->unsignedSmallInteger('duration_days');
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('subscriptions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('plan_id')->constrained('plans')->restrictOnDelete();
            $table->string('status', 16)->default('pending');
            $table->string('tx_ref', 64)->unique();
            $table->unsignedInteger('amount_mwk');
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->json('provider_data')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status', 'ends_at']);
        });

        Schema::create('document_purchases', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('document_id', 128);
            $table->string('status', 16)->default('pending');
            $table->string('tx_ref', 64)->unique();
            $table->unsignedInteger('amount_mwk');
            $table->timestamp('purchased_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->json('provider_data')->nullable();
            $table->timestamps();

            $table->foreign('document_id')->references('id')->on('documents')->cascadeOnDelete();
            $table->index(['user_id', 'status', 'document_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('document_purchases');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('plans');
    }
};
