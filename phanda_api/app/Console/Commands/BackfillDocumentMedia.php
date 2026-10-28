<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Models\DocumentVersion;
use App\Services\DocumentPublisher;
use Illuminate\Console\Command;
use Throwable;

/**
 * Imports versions that were stored before Media Library into the media table,
 * keeping their version numbers and checksums intact.
 */
final class BackfillDocumentMedia extends Command
{
    protected $signature = 'library:media-backfill
                            {--document= : Only backfill one document id}';

    protected $description = 'Move existing document version files into Spatie Media Library';

    public function handle(DocumentPublisher $publisher): int
    {
        $query = DocumentVersion::query()
            ->whereNull('media_id')
            ->with('document')
            ->orderBy('document_id')
            ->orderBy('version');

        if ($this->option('document') !== null) {
            $document = Document::query()->find($this->option('document'));

            if ($document === null) {
                $this->error('No document exists with that ID.');

                return self::FAILURE;
            }

            $query->where('document_id', $document->id);
        }

        $moved = 0;
        $failed = 0;

        foreach ($query->cursor() as $version) {
            try {
                $publisher->importExisting($version->document, $version);
                $moved++;
            } catch (Throwable $exception) {
                $failed++;
                $this->warn(sprintf(
                    '%s v%d: %s',
                    $version->document_id,
                    $version->version,
                    $exception->getMessage()
                ));
            }
        }

        $this->info("Imported {$moved} version(s) into Media Library; {$failed} failed.");

        return $failed === 0 ? self::SUCCESS : self::FAILURE;
    }
}
