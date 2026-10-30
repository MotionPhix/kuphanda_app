<?php

declare(strict_types=1);

namespace App\Services\Library;

use App\Models\Document;

/**
 * How big is a structured paper, in the units a learner counts in?
 *
 * The `pages` column is an import artefact: the maths paper is six scanned
 * pages, the mechanics sample claims seventy-two, and neither number describes
 * what a student works through. Question count and marks come from the blocks
 * themselves, and are read through BlockAudit so the display can never disagree
 * with the gate that decides whether the paper may be published.
 */
final class DocumentStats
{
    public function __construct(private readonly BlockAudit $audit) {}

    /**
     * @return array{questions: int, marks: int}|null null when there are no blocks
     */
    public function for(Document $document): ?array
    {
        $payload = is_array($document->blocks) ? $document->blocks : [];
        $blocks = $payload['blocks'] ?? [];

        if (! is_array($blocks) || $blocks === []) {
            return null;
        }

        $report = $this->audit->inspect(
            $blocks,
            isset($payload['subtitle']) ? (string) $payload['subtitle'] : null,
        );

        return ['questions' => $report['questions'], 'marks' => $report['marks']];
    }
}
