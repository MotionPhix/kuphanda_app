<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use Illuminate\Console\Command;

/**
 * Removes a document from the catalogue without deleting its versions.
 *
 * Existing offline marks remain, but the next sync reports them as not
 * entitled, so clients delete the downloaded file. Re-publishing later restores
 * access without re-marking.
 */
final class UnpublishDocument extends Command
{
    protected $signature = 'library:unpublish {document : Document ID}';

    protected $description = 'Hide a document and revoke offline access on the next sync';

    public function handle(): int
    {
        $document = Document::query()->find($this->argument('document'));

        if ($document === null) {
            $this->error('No document exists with that ID.');

            return self::FAILURE;
        }

        $document->forceFill(['is_published' => false])->save();
        $document->touch();

        $this->info("Unpublished {$document->id}.");
        $this->line('Offline copies are revoked on the next sync; versions are kept.');

        return self::SUCCESS;
    }
}
