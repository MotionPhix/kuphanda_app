<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Who has read what a teacher set.
 *
 * Until now "done" was a private note in the app: the learner's own reading
 * progress, on the learner's own phone. A teacher could see that a class existed
 * and that a paper was set, but not whether anyone had read it. This table is the
 * class's shared record, one row per learner per assignment.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('assignment_completions', function (Blueprint $table): void {
            $table->id();
            $table->string('assignment_id', 32);
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('completed_at');
            $table->timestamps();

            // Reading the same paper twice is not two completions.
            $table->unique(['assignment_id', 'user_id']);
            $table->foreign('assignment_id')->references('id')->on('classroom_assignments')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assignment_completions');
    }
};
