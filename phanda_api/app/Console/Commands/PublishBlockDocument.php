<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\Library\DocumentPublisher;
use Illuminate\Console\Command;
use RuntimeException;

final class PublishBlockDocument extends Command
{
    protected $signature = 'documents:publish {document : Document id} {--force : Publish despite unresolved issues}';

    protected $description = 'Publish a structured paper, refusing when its marks do not reconcile';

    public function handle(DocumentPublisher $publisher): int
    {
        $document = Document::query()->find($this->argument('document'));

        if ($document === null) {
            $this->error('No such document.');

            return self::FAILURE;
        }

        try {
            $report = $publisher->publish($document, (bool) $this->option('force'));
        } catch (RuntimeException $error) {
            $this->error($error->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Published %s: %d questions, %d marks%s',
            $document->id,
            $report['questions'],
            $report['marks'],
            $this->option('force') ? ' (forced)' : ''
        ));

        return self::SUCCESS;
    }
}
