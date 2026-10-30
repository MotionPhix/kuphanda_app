<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Classes a teacher runs and a learner joins with a code.
 *
 * Until now the app's Classes tab was built entirely inside the binary: three
 * classes with teacher names and learner counts, joinable only by the three
 * codes that shipped with it. This is the service behind that screen.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('classrooms', function (Blueprint $table): void {
            $table->string('id', 32)->primary();
            // Six characters, read out loud in a classroom: no O/0 or I/1.
            $table->string('code', 8)->unique();
            $table->string('name');
            $table->unsignedTinyInteger('form');
            $table->string('subject_id', 64)->nullable();
            $table->foreignId('teacher_id')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            $table->index('teacher_id');
        });

        Schema::create('classroom_members', function (Blueprint $table): void {
            $table->string('classroom_id', 32);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('joined_at');

            $table->primary(['classroom_id', 'user_id']);
            $table->foreign('classroom_id')->references('id')->on('classrooms')->cascadeOnDelete();
        });

        Schema::create('classroom_assignments', function (Blueprint $table): void {
            $table->string('id', 32)->primary();
            $table->string('classroom_id', 32);
            $table->string('document_id', 128);
            $table->date('due_date')->nullable();
            $table->foreignId('set_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();

            // Setting the same paper twice in one class is a mistake, not a plan.
            $table->unique(['classroom_id', 'document_id']);
            $table->foreign('classroom_id')->references('id')->on('classrooms')->cascadeOnDelete();
            $table->foreign('document_id')->references('id')->on('documents')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('classroom_assignments');
        Schema::dropIfExists('classroom_members');
        Schema::dropIfExists('classrooms');
    }
};
