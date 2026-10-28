<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('document_versions', function (Blueprint $table): void {
            $table->foreignId('media_id')
                ->nullable()
                ->after('checksum')
                ->constrained('media')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('document_versions', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('media_id');
        });
    }
};
