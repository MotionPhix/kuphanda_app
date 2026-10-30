<?php

declare(strict_types=1);

namespace App\Services\Library;

use App\Models\Document;
use RuntimeException;

/**
 * The only supported way to make a document visible.
 *
 * Publishing runs two checks. First, does the document have anything to read at
 * all — blocks or a file? A record with neither is invisible in every sense
 * except the catalogue, and publishing one puts a dead entry in front of
 * learners. Second, for a structured paper, do its marks reconcile?
 *
 * Either check can be overridden with --force, and that override is logged
 * rather than silent: shipping something unreconciled or unreadable must be a
 * decision someone made on the record.
 */
final class DocumentPublisher
{
    public function __construct(
        private readonly BlockAudit $audit,
        private readonly DocumentReadiness $readiness,
    ) {}

    /**
     * @return array{questions: int, marks: int, issues: list<string>}
     *
     * @throws RuntimeException when the document has nothing to read, or its marks do
     *                          not reconcile, and $force is false.
     */
    public function publish(Document $document, bool $force = false): array
    {
        if (! $this->readiness->isReadable($document)) {
            $message = sprintf(
                '%s cannot be published: %s — a learner would see a paper they cannot open',
                $document->id,
                $this->readiness->problem($document),
            );

            if (! $force) {
                throw new RuntimeException($message.'. Add content, or pass --force to publish anyway.');
            }

            logger()->warning('Published a document with nothing to read', [
                'document' => $document->id,
            ]);
        }

        $payload = is_array($document->blocks) ? $document->blocks : [];
        $blocks = $payload['blocks'] ?? [];
        $report = $this->audit->inspect(
            is_array($blocks) ? $blocks : [],
            isset($payload['subtitle']) ? (string) $payload['subtitle'] : null,
        );

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
