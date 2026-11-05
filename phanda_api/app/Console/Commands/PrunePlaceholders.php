<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\DocumentReadiness;
use Illuminate\Console\Command;

/**
 * Deletes catalogue records that carry no content at all.
 *
 * `documents:readiness` demotes them to draft, which keeps a dead row in the
 * database forever. A placeholder is not a draft of anything: nobody is going to
 * publish it, and leaving it behind means the next person to list "all
 * documents" has to work out again which rows are real. This removes them.
 *
 * A record that a learner has acted on is never deleted: a purchase, an offline
 * mark or a class assignment is a fact about somebody's account, and the row
 * stays (unpublished) so the history still resolves.
 */
final class PrunePlaceholders extends Command
{
    protected $signature = 'library:prune
        {--delete : Delete the placeholders instead of only listing them}
        {--include-drafts : Also consider records that are already unpublished}';

    protected $description = 'Delete catalogue records that have no blocks, no file and no guide';

    public function handle(DocumentReadiness $readiness): int
    {
        $query = Document::query()->orderBy('id');

        if (! $this->option('include-drafts')) {
            $query->where('is_published', true);
        }

        $candidates = $query->get()
            ->reject(fn (Document $document): bool => $readiness->isReadable($document));

        if ($candidates->isEmpty()) {
            $this->info('No placeholders found.');

            return self::SUCCESS;
        }

        $deleted = 0;
        $kept = 0;

        foreach ($candidates as $document) {
            if ($this->inUse($document)) {
                // The row still resolves a purchase or an assignment, so it
                // stays — but it must not keep advertising itself as catalogue
                // content when there is nothing to open.
                if ($document->is_published) {
                    $document->forceFill(['is_published' => false])->save();
                }

                $kept++;
                $this->warn(sprintf(
                    '    kept %s — purchased, marked offline or set as class work (unpublished)',
                    $document->id,
                ));

                continue;
            }

            if (! $this->option('delete')) {
                $this->line(sprintf('    %s — %s', $document->id, $document->title));

                continue;
            }

            $document->delete();
            $deleted++;
            $this->line(sprintf('    deleted %s — %s', $document->id, $document->title));
        }

        if (! $this->option('delete')) {
            $this->newLine();
            $this->line(sprintf(
                '%d placeholder(s) listed, %d kept because they are in use. Re-run with --delete to remove the rest.',
                $candidates->count() - $kept,
                $kept,
            ));

            return self::SUCCESS;
        }

        $this->info(sprintf('Deleted %d placeholder(s); %d kept because they are in use.', $deleted, $kept));

        return self::SUCCESS;
    }

    private function inUse(Document $document): bool
    {
        return $document->purchases()->exists()
            || $document->offlineMarks()->exists()
            || $document->assignments()->exists();
    }
}
