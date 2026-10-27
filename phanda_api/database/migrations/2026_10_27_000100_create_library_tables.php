<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subjects', function (Blueprint $table): void {
            $table->string('id', 64)->primary();
            $table->string('name');
            $table->string('short_name', 64);
            $table->string('emoji', 16)->nullable();
            $table->string('color', 16)->default('#0F5B3A');
            $table->json('forms');
            $table->text('blurb')->nullable();
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('documents', function (Blueprint $table): void {
            $table->string('id', 128)->primary();
            $table->string('subject_id', 64);
            $table->string('title');
            $table->unsignedTinyInteger('form');
            $table->string('kind', 32);
            $table->text('description')->nullable();
            $table->unsignedInteger('pages')->default(1);
            $table->unsignedSmallInteger('year')->nullable();
            $table->unsignedTinyInteger('paper_number')->nullable();
            $table->string('session', 16)->nullable();
            $table->unsignedSmallInteger('total_marks')->nullable();
            $table->unsignedSmallInteger('duration_minutes')->nullable();
            $table->string('access_tier', 16)->default('free');
            $table->string('author')->default('Kuphanda Library');
            $table->string('publisher')->nullable();
            $table->string('language', 32)->default('English');
            $table->json('tags')->nullable();
            $table->string('guide_id', 128)->nullable();
            $table->boolean('featured')->default(false);
            $table->boolean('is_published')->default(true);
            $table->unsignedInteger('latest_version')->default(0);
            $table->timestamp('content_updated_at')->nullable();
            $table->timestamps();

            $table->foreign('subject_id')->references('id')->on('subjects')->cascadeOnUpdate()->restrictOnDelete();
            $table->index(['subject_id', 'form']);
            $table->index(['kind', 'form']);
            $table->index('is_published');
        });

        Schema::create('document_versions', function (Blueprint $table): void {
            $table->id();
            $table->string('document_id', 128);
            $table->unsignedInteger('version');
            $table->string('disk', 32)->default('local');
            $table->string('path');
            $table->string('file_name');
            $table->string('mime_type', 64)->default('application/pdf');
            $table->unsignedBigInteger('size_bytes');
            $table->unsignedInteger('page_count')->default(1);
            $table->string('checksum', 64);
            $table->string('notes')->nullable();
            $table->timestamp('published_at');
            $table->timestamps();

            $table->foreign('document_id')->references('id')->on('documents')->cascadeOnDelete();
            $table->unique(['document_id', 'version']);
        });

        Schema::create('offline_documents', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('document_id', 128);
            $table->unsignedInteger('downloaded_version')->nullable();
            $table->timestamp('marked_at');
            $table->timestamp('last_synced_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->foreign('document_id')->references('id')->on('documents')->cascadeOnDelete();
            $table->unique(['user_id', 'document_id']);
            $table->index(['user_id', 'updated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('offline_documents');
        Schema::dropIfExists('document_versions');
        Schema::dropIfExists('documents');
        Schema::dropIfExists('subjects');
    }
};
