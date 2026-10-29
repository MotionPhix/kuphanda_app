<?php

declare(strict_types=1);

namespace App\Services\Library;

use App\Models\Document;
use RuntimeException;

/**
 * The only supported way to make a structured paper visible.
 *
 * Publishing runs the audit first. A paper that does not reconcile stays a draft
 * unless someone passes --force, and that override is logged rather than silent:
 * an unreconciled total must be a decision, not an accident.
 */
final class DocumentPublisher
{
    public function __construct(private readonly BlockAudit $audit) {}

    /**
     * @return array{questions: int, marks: int, issues: list<string>}
     *
     * @throws RuntimeException when the paper does not reconcile and $force is false.
     */
    public function publish(Document $document, bool $force = false): array
    {
        $blocks = $document->blocks['blocks'] ?? [];
        $report = $this->audit->inspect($blocks, $document->blocks['subtitle'] ?? null);

        if ($report['issues'] !== [] && ! $force) {
            throw new RuntimeException(sprintf(
                "%s has %d unresolved issue(s); fix them or publish with --force.\n  %s",
                $document->id,
                count($report['issues']),
                implode("\n  ", $report['issues'])
            ));
        }

        if ($report['issues'] !== [] && $force) {
            logger()->warning('Published with unresolved block issues', [
                'document' => $document->id,
                'issues' => $report['issues'],
            ]);
        }

        $document->forceFill(['is_published' => true])->save();

        return $report;
    }
}
