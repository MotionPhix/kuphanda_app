<?php

declare(strict_types=1);

namespace App\Services\Library;

use App\Models\Document;

/**
 * Can a learner actually open this document?
 *
 * A published record with no block content and no file is a dead entry: it
 * appears in the library, its detail page offers a button that cannot do
 * anything, and no amount of reading changes that. This turned out to be seven
 * of twelve live documents, so the check belongs at the point where visibility
 * is granted rather than only in the screen that renders it.
 *
 * The rules live here so the publisher, the audit command and the tests agree;
 * a second copy is how a document passes one check and fails another.
 */
final class DocumentReadiness
{
    /** Number of top-level blocks, or 0 when the record carries none. */
    public function blocks(Document $document): int
    {
        $blocks = is_array($document->blocks) ? ($document->blocks['blocks'] ?? []) : [];

        return is_array($blocks) ? count($blocks) : 0;
    }

    public function hasFile(Document $document): bool
    {
        return $document->getMedia('files')->isNotEmpty() || $document->latest_version > 0;
    }

    public function isReadable(Document $document): bool
    {
        return $this->blocks($document) > 0
            || $this->hasFile($document)
            || $this->hasBundledGuide($document);
    }

    /**
     * A guide's sections ship inside the app, keyed by guide_id, so the record
     * needs no blocks and no file to be readable. Judging it by the server's
     * payload alone would bury working content.
     */
    public function hasBundledGuide(Document $document): bool
    {
        return is_string($document->guide_id) && $document->guide_id !== '';
    }

    /** Why a document cannot be read, or null when it can. */
    public function problem(Document $document): ?string
    {
        if ($this->isReadable($document)) {
            return null;
        }

        return 'nothing to read: no block content and no file';
    }
}
