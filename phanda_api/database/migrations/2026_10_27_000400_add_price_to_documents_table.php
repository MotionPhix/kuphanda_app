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
            // Price of a single-document purchase. Zero means the document is
            // only available through a subscription (or is free).
            $table->unsignedInteger('price_mwk')->default(0)->after('access_tier');
        });
    }

    public function down(): void
    {
        Schema::table('documents', function (Blueprint $table): void {
            $table->dropColumn('price_mwk');
        });
    }
};
