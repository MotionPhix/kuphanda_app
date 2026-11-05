<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\DocumentReadiness;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;

/**
 * Brings a database in line with the catalogue the code ships.
 *
 * The catalogue is owned by the library team and lives in the seeders, but the
 * seeders only ever ran by hand: deploying the code left a server with the old
 * rows, and nothing in `deploy.sh` noticed. This runs the two catalogue seeders
 * in the right order, reports what a learner can actually open, and optionally
 * removes records left over from before structured content existed.
 */
final class SyncLibrary extends Command
{
    protected $signature = 'library:sync
        {--prune : Delete placeholders left over from an older catalogue}';

    protected $description = 'Seed the code-owned catalogue and report what is readable';

    public function handle(DocumentReadiness $readiness): int
    {
        // PlanSeeder belongs here too. A server synced without it has documents
        // but no prices, so the subscription page lists nothing — which reads as
        // a broken screen rather than a seeder that never ran.
        $seeders = [
            'Database\\Seeders\\LibrarySeeder',
            'Database\\Seeders\\BlockDocumentSeeder',
            'Database\\Seeders\\PlanSeeder',
        ];

        foreach ($seeders as $seeder) {
            $this->line('Seeding '.class_basename($seeder).'…');
            Artisan::call('db:seed', ['--class' => $seeder, '--force' => true]);
        }

        $published = Document::query()->where('is_published', true)->orderBy('id')->get();
        $unreadable = $published->reject(fn (Document $document): bool => $readiness->isReadable($document));

        $this->newLine();
        $this->line(sprintf(
            '%d published · %d readable · %d with nothing to read',
            $published->count(),
            $published->count() - $unreadable->count(),
            $unreadable->count(),
        ));

        foreach ($published as $document) {
            $this->line(sprintf('    %-32s %s', $document->id, $readiness->isReadable($document) ? 'readable' : 'NOT READABLE'));
        }

        if ($unreadable->isEmpty()) {
            return self::SUCCESS;
        }

        if (! $this->option('prune')) {
            $this->newLine();
            $this->warn('Some published records cannot be opened. Re-run with --prune to remove the leftovers.');

            return self::SUCCESS;
        }

        $this->newLine();
        $this->call('library:prune', ['--delete' => true]);

        return self::SUCCESS;
    }
}
