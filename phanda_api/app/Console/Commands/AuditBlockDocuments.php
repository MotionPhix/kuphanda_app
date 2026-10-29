<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use Illuminate\Console\Command;

/**
 * Checks that a structured paper adds up before it is trusted.
 *
 * A wrong mark total is worse than no total: a learner practises against it and
 * a teacher cannot award a fair score. This reports rather than repairs, because
 * only a human knows whether a missing 2 marks belongs to part (b) or (c).
 */
final class AuditBlockDocuments extends Command
{
    protected $signature = 'documents:audit-blocks {document? : A single document id}';

    protected $description = 'Verify that block documents reconcile their marks and structure';

    public function handle(): int
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
            $blocks = $document->blocks['blocks'] ?? [];
            $questions = array_values(array_filter(
                $blocks,
                static fn (array $block): bool => ($block['type'] ?? null) === 'question'
            ));

            $sum = 0;
            $issues = [];

            foreach ($questions as $question) {
                $label = $question['label'] ?? '?';
                $parts = $question['parts'] ?? [];
                $partSum = 0;
                $missing = 0;

                foreach ($parts as $part) {
                    if (! isset($part['marks'])) {
                        $missing++;
                        continue;
                    }

                    $partSum += (int) $part['marks'];
                }

                $declared = isset($question['marks']) ? (int) $question['marks'] : null;

                if ($parts !== [] && $declared !== null && $partSum !== $declared) {
                    $issues[] = sprintf(
                        '%s: parts total %d but question says %d',
                        $label,
                        $partSum,
                        $declared
                    );
                }

                if ($missing > 0) {
                    $issues[] = sprintf('%s: %d part(s) without marks', $label, $missing);
                }

                $sum += $declared ?? $partSum;

                if (trim((string) ($question['text'] ?? '')) === '') {
                    $issues[] = sprintf('%s: empty stem', $label);
                }
            }

            $expected = null;

            if (preg_match('/(\d{2,3})\s*marks/', (string) $document->blocks['subtitle'] ?? '', $match) === 1) {
                $expected = (int) $match[1];
            }

            if ($expected !== null && $sum !== $expected) {
                $issues[] = sprintf('total %d marks, document states %d (short by %d)', $sum, $expected, $expected - $sum);
            }

            $status = $issues === [] ? '<fg=green>ok</>' : '<fg=yellow>needs review</>';
            $this->line(sprintf('%s — %d questions, %d marks: %s', $document->id, count($questions), $sum, $status));

            foreach ($issues as $issue) {
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
