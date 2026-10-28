<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('documents')
            ->where('id', 'sample-howto')
            ->update([
                'description' => 'A short guide to finding papers, subscribing, downloading for offline reading and keeping notes.',
                'updated_at' => now(),
            ]);
    }

    public function down(): void
    {
        DB::table('documents')
            ->where('id', 'sample-howto')
            ->update([
                'description' => 'A short guide to finding documents, attaching PDFs, keeping notes and working offline. Ships with the app.',
                'updated_at' => now(),
            ]);
    }
};
