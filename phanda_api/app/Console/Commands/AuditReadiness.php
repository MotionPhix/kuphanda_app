<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\DocumentReadiness;
use Illuminate\Console\Command;

/**
 * Finds published documents that a learner cannot open.
 *
 * These come from catalogue rows seeded before structured content existed: the
 * record describes a paper, nothing backs it, and the library still lists it.
 * The command reports by default and only demotes to draft when asked, because
 * removing a paper from a learner's library is an editorial decision.
 */
final class AuditReadiness extends Command
{
    protected $signature = 'documents:readiness
        {--unpublish : Move unreadable published documents back to draft}';

    protected $description = 'Report published documents that have no block content and no file';

    public function handle(DocumentReadiness $readiness): int
    {
        $documents = Document::query()->where('is_published', true)->orderBy('id')->get();

        if ($documents->isEmpty()) {
            $this->warn('No published documents.');

            return self::SUCCESS;
        }

        $unreadable = $documents->reject(fn (Document $document) => $readiness->isReadable($document));

        $this->line(sprintf(
            '%d published · %d readable · %d with nothing to read',
            $documents->count(),
            $documents->count() - $unreadable->count(),
            $unreadable->count(),
        ));

        foreach ($unreadable as $document) {
            $this->line(sprintf(
                '    %s — %s',
                $document->id,
                $readiness->problem($document),
            ));
        }

        if ($unreadable->isEmpty()) {
            return self::SUCCESS;
        }

        if (! $this->option('unpublish')) {
            $this->newLine();
            $this->line('Re-run with --unpublish to move these back to draft.');

            return self::SUCCESS;
        }

        foreach ($unreadable as $document) {
            $document->forceFill(['is_published' => false])->save();
        }

        $this->info(sprintf('Unpublished %d document(s).', $unreadable->count()));

        return self::SUCCESS;
    }
}
