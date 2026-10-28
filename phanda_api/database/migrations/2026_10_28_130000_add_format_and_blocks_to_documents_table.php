<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('documents', function (Blueprint $table): void {
            // pdf    – the source file is the only representation
            // blocks – reflowable structured content, PDF optional
            // hybrid – both, so the reader can fall back to the scan
            $table->string('format', 16)->default('pdf')->after('kind');

            // Structured content, versioned with the row. Shape:
            // { "subtitle": string|null, "blocks": [ ... ] }
            $table->json('blocks')->nullable()->after('format');
        });
    }

    public function down(): void
    {
        Schema::table('documents', function (Blueprint $table): void {
            $table->dropColumn(['format', 'blocks']);
        });
    }
};
