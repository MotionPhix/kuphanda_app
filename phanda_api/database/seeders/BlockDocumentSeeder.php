<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Document;
use Illuminate\Database\Seeder;

/**
 * Attaches one real structured document so the reflowable reader has something
 * to open. Idempotent: re-seeding does not overwrite editorial changes made
 * after the first import.
 */
final class BlockDocumentSeeder extends Seeder
{
    private const TARGET = 'ref-msce-physics-mechanics';

    private const FILE = 'blocks-mechanics.json';

    private const PAPER_ID = 'ref-msce-maths-2002-p1';

    private const PAPER_FILE = 'blocks-msce-maths-2002-p1.json';

    private const AGRICULTURE_ID = 'ref-msce-agriculture-2017-p1';

    private const AGRICULTURE_FILE = 'blocks-msce-agriculture-2017-p1.json';

    public function run(): void
    {
        // Independent of the mechanics sample so a partially seeded database
        // still gets the published paper.
        $this->publishPaper();

        // Stored unpublished on purpose: the paper only reaches learners if
        // `documents:publish` accepts its audit, so a parse regression cannot
        // slip into the catalogue through a seeder run.
        $this->storeAgriculturePaper();

        $document = Document::query()->find(self::TARGET);

        if ($document === null) {
            $this->command?->warn('Block sample skipped: '.self::TARGET.' is missing.');

            return;
        }

        if (! empty($document->blocks['blocks'])) {
            return;
        }


        $path = database_path('seeders/files/'.self::FILE);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Block sample skipped: '.self::FILE.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        $blocks = $json['blocks'] ?? [];

        if (! is_array($blocks) || $blocks === []) {
            $this->command?->warn('Block sample skipped: no blocks in the file.');

            return;
        }

        $document->forceFill([
            'format' => 'hybrid',
            'blocks' => [
                'subtitle' => $json['subtitle'] ?? null,
                'blocks' => $blocks,
            ],
        ])->save();

        $this->command?->info(sprintf(
            'Attached %d structured blocks to %s.',
            count($blocks),
            $document->id,
        ));
    }

    /**
     * Publishes the transcribed MSCE paper as a free catalogue document, so the
     * structured reader can be used on a real paper end to end.
     */
    private function publishPaper(): void
    {
        $path = database_path('seeders/files/'.self::PAPER_FILE);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Paper skipped: '.self::PAPER_FILE.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        Document::query()->updateOrCreate(
            ['id' => self::PAPER_ID],
            [
                'subject_id' => 'mathematics',
                'title' => $json['title'] ?? 'Mathematics Paper I',
                'form' => 4,
                'kind' => 'pastPaper',
                'format' => 'blocks',
                'blocks' => [
                    'subtitle' => $json['subtitle'] ?? null,
                    'blocks' => $json['blocks'] ?? [],
                ],
                'description' => 'Full Paper I transcribed into reflowable questions.',
                'pages' => 6,
                'year' => 2002,
                'paper_number' => 1,
                'access_tier' => 'free',
                'price_mwk' => 0,
                'author' => 'MANEB',
                'language' => 'English',
                'is_published' => true,
            ],
        );

        $this->command?->info('Published '.self::PAPER_ID.'.');
    }

    /**
     * Imports the parsed Agriculture paper as a draft.
     */
    private function storeAgriculturePaper(): void
    {
        $path = database_path('seeders/files/'.self::AGRICULTURE_FILE);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Paper skipped: '.self::AGRICULTURE_FILE.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        Document::query()->updateOrCreate(
            ['id' => self::AGRICULTURE_ID],
            [
                'subject_id' => 'agriculture',
                'title' => $json['title'] ?? 'Agriculture Paper 1',
                'form' => 4,
                'kind' => 'pastPaper',
                'format' => 'blocks',
                'blocks' => [
                    'subtitle' => $json['subtitle'] ?? null,
                    'blocks' => $json['blocks'] ?? [],
                ],
                'description' => 'Mock Paper 1 with nested parts, reflowable on a phone.',
                'pages' => 13,
                'year' => 2017,
                'paper_number' => 1,
                'access_tier' => 'free',
                'price_mwk' => 0,
                'author' => 'Mzuzu Diocese',
                'language' => 'English',
            ],
        );

        $this->command?->info('Stored draft '.self::AGRICULTURE_ID.'.');
    }
}
