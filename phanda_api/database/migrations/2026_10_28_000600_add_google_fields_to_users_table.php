<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('google_id', 64)->nullable()->unique()->after('id');
            $table->string('first_name', 80)->nullable()->after('name');
            $table->string('last_name', 80)->nullable()->after('first_name');
            $table->string('avatar_url', 2048)->nullable()->after('email');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['google_id']);
            $table->dropColumn(['google_id', 'first_name', 'last_name', 'avatar_url']);
        });
    }
};
