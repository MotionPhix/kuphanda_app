<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\BlockAudit;
use Illuminate\Console\Command;

/**
 * Records a reviewer's mark allocation against a part.
 *
 * The PDF text layer does not always carry per-part marks, and guessing them
 * would be inventing an exam. This command is how a teacher corrects one part
 * at a time; the audit then shows whether the paper reconciles.
 */
final class SetQuestionMarks extends Command
{
    protected $signature = 'documents:set-marks
        {document : Document id}
        {question : Question label, e.g. 6}
        {part : Part label, e.g. b; use "." for the question itself}
        {marks : Marks to record}
        {--dry-run : Show the effect without saving}';

    protected $description = 'Set the marks for one part of a structured paper';

    public function handle(BlockAudit $audit): int
    {
        $document = Document::query()->find($this->argument('document'));

        if ($document === null || empty($document->blocks['blocks'])) {
            $this->error('No structured document with that id.');

            return self::FAILURE;
        }

        $blocks = $document->blocks;
        $wanted = rtrim((string) $this->argument('question'), '.');
        $part = (string) $this->argument('part');
        $marks = (int) $this->argument('marks');
        $changed = false;

        foreach ($blocks['blocks'] as $index => $block) {
            if (($block['type'] ?? null) !== 'question') {
                continue;
            }

            if (rtrim((string) ($block['label'] ?? ''), '.') !== $wanted) {
                continue;
            }

            if ($part === '.' || $part === '') {
                $blocks['blocks'][$index]['marks'] = $marks;
                $changed = true;

                break;
            }

            $target = rtrim($part, '.() ');
            foreach ($block['parts'] ?? [] as $partIndex => $existing) {
                $label = rtrim((string) ($existing['label'] ?? ''), '.() ');
                if ($label !== $target) {
                    continue;
                }

                $blocks['blocks'][$index]['parts'][$partIndex]['marks'] = $marks;
                $changed = true;

                break 2;
            }
        }

        if (! $changed) {
            $this->error('Question or part not found.');

            return self::FAILURE;
        }

        $report = $audit->inspect($blocks['blocks'], $blocks['subtitle'] ?? null);
        $this->line(sprintf('Total would be %d marks.', $report['marks']));

        foreach ($report['issues'] as $issue) {
            $this->line('    '.$issue);
        }

        if ($this->option('dry-run')) {
            $this->warn('Dry run: nothing saved.');

            return self::SUCCESS;
        }

        $document->blocks = $blocks;
        $document->save();

        $this->info('Saved. Publish with documents:publish once the audit is clean.');

        return self::SUCCESS;
    }
}
