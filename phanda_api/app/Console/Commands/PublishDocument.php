<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Services\DocumentPublisher;
use Illuminate\Console\Command;
use Throwable;

/**
 * Publishes a new immutable version of a library document.
 *
 * The app never accepts student uploads. Library staff run this command with a
 * PDF they are allowed to distribute; every publish creates a new version so
 * learners on an older copy can finish reading before they refresh.
 */
final class PublishDocument extends Command
{
    protected $signature = 'library:publish
        {document : Document ID, e.g. sample-howto}
        {file : Path to the PDF on this machine}
        {--pages= : Page count (estimated from the PDF when omitted)}
        {--notes= : Internal release note}';

    protected $description = 'Publish a new version of a document and make it downloadable';

    private const MAX_BYTES = 50 * 1024 * 1024;

    public function handle(): int
    {
        /** @var Document|null $document */
        $document = Document::query()->find($this->argument('document'));

        if ($document === null) {
            $this->error('No document exists with that ID.');

            return self::FAILURE;
        }

        $path = (string) $this->argument('file');

        if (! is_file($path) || ! is_readable($path)) {
            $this->error('The file does not exist or cannot be read.');

            return self::FAILURE;
        }

        $size = (int) filesize($path);

        if ($size === 0) {
            $this->error('The file is empty.');

            return self::FAILURE;
        }

        if ($size > self::MAX_BYTES) {
            $this->error('The file is larger than the 50 MB limit.');

            return self::FAILURE;
        }

        $contents = file_get_contents($path);

        if ($contents === false || ! str_starts_with($contents, '%PDF')) {
            $this->error('That file is not a PDF.');

            return self::FAILURE;
        }

        $pages = $this->option('pages');

        if ($pages !== null && (! ctype_digit((string) $pages) || (int) $pages < 1)) {
            $this->error('--pages must be a positive integer.');

            return self::FAILURE;
        }

        $pageCount = $pages !== null ? (int) $pages : $this->estimatePages($contents);

        try {
            $version = app(DocumentPublisher::class)->publish(
                $document,
                $path,
                $pageCount,
                $this->option('notes'),
            );
        } catch (Throwable $exception) {
            report($exception);
            $this->error('Publishing failed: '.$exception->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Published %s v%d (%s, %d pages, %s).',
            $document->id,
            $version->version,
            $this->humanSize($version->size_bytes),
            $version->page_count,
            substr($version->checksum, 0, 12)
        ));
        $this->line('Learners will see it as an update on their next sync.');

        return self::SUCCESS;
    }

    private function estimatePages(string $contents): int
    {
        $count = preg_match_all('/\/Type\s*\/Page[^s]/', $contents);

        return is_int($count) && $count > 0 ? $count : 1;
    }

    private function humanSize(int $bytes): string
    {
        return $bytes >= 1024 * 1024
            ? sprintf('%.1f MB', $bytes / (1024 * 1024))
            : sprintf('%d KB', max(1, (int) round($bytes / 1024)));
    }
}
