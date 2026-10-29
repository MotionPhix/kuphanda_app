<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\BlockAudit;
use Illuminate\Console\Command;

/**
 * Checks that structured papers add up before they are trusted.
 *
 * The rules live in BlockAudit so this command, the publisher and the tests all
 * agree; a second copy of the arithmetic here is how a paper can pass one check
 * and fail another.
 */
final class AuditBlockDocuments extends Command
{
    protected $signature = 'documents:audit-blocks {document? : A single document id}';

    protected $description = 'Verify that block documents reconcile their marks and structure';

    public function handle(BlockAudit $audit): int
    {
        $query = Document::query()->whereNotNull('blocks');

        if ($id = $this->argument('document')) {
            $query->whereKey($id);
        }

        $documents = $query->get();

        if ($documents->isEmpty()) {
            $this->warn('No structured documents found.');

            return self::SUCCESS;
        }

        $failures = 0;

        foreach ($documents as $document) {
            $report = $audit->inspect(
                $document->blocks['blocks'] ?? [],
                $document->blocks['subtitle'] ?? null,
            );

            $status = $report['issues'] === [] ? '<fg=green>ok</>' : '<fg=yellow>needs review</>';

            $this->line(sprintf(
                '%s — %d questions, %d marks: %s',
                $document->id,
                $report['questions'],
                $report['marks'],
                $status,
            ));

            foreach ($report['issues'] as $issue) {
                $this->line('    '.$issue);
                $failures++;
            }
        }

        $this->newLine();
        $this->line($failures === 0
            ? 'All structured documents reconcile.'
            : sprintf('%d issue(s) to review before publishing.', $failures));

        return self::SUCCESS;
    }
}
