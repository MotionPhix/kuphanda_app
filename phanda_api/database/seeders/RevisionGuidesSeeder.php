<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Document;
use Illuminate\Database\Seeder;

/**
 * Seeds the two Mathematics revision guides Kuphanda wrote itself.
 *
 * Unlike BlockDocumentSeeder these are not transcriptions of anybody's paper, so
 * there is no marks audit to pass: `author` says Kuphanda, the subtitle says so,
 * and no year or paper number is set, because claiming a paper reference would
 * imply an external examination that does not exist.
 *
 * They exist for a second reason as well. Between them they use every block type
 * in the schema - including `figure` as a drawn diagram, `divider`, a standalone
 * `table` and an `answer` block - where the only other live documents exercised
 * a handful. Content is the cheapest test the reader can get.
 */
final class RevisionGuidesSeeder extends Seeder
{
    /** @var array<string, array{file: string, form: int, tags: list<string>}> */
    private const GUIDES = [
        'ref-guide-circle-geometry' => [
            'file' => 'blocks-maths-circle-geometry.json',
            'form' => 4,
            'tags' => ['geometry', 'revision'],
        ],
        'ref-guide-data-handling' => [
            'file' => 'blocks-maths-data-handling.json',
            'form' => 3,
            'tags' => ['data handling', 'revision'],
        ],
    ];

    public function run(): void
    {
        foreach (self::GUIDES as $id => $guide) {
            $this->seedGuide($id, $guide['file'], $guide['form'], $guide['tags']);
        }
    }

    /**
     * @param  list<string>  $tags
     */
    private function seedGuide(string $id, string $file, int $form, array $tags): void
    {
        $path = database_path('seeders/files/'.$file);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Guide skipped: '.$file.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        /** @var list<array<string, mixed>> $blocks */
        $blocks = is_array($json['blocks'] ?? null) ? $json['blocks'] : [];

        Document::query()->updateOrCreate(
            ['id' => $id],
            [
                'subject_id' => 'mathematics',
                'title' => $json['title'] ?? 'Revision guide',
                'form' => $form,
                'kind' => 'guide',
                'format' => 'blocks',
                'blocks' => [
                    'subtitle' => $json['subtitle'] ?? null,
                    'blocks' => $blocks,
                ],
                'description' => $json['subtitle'] ?? null,
                'pages' => $this->pageCount($blocks),
                'access_tier' => 'free',
                'price_mwk' => 0,
                'author' => 'Kuphanda',
                'language' => 'English',
                'is_published' => true,
            ],
        );

        $this->command?->info('Seeded '.$id.' ('.$this->pageCount($blocks).' pages).');
    }

    /**
     * @param  list<array<string, mixed>>  $blocks
     */
    private function pageCount(array $blocks): int
    {
        $pages = 1;

        foreach ($blocks as $block) {
            $page = $block['page'] ?? null;
            if (is_int($page) && $page > $pages) {
                $pages = $page;
            }
        }

        return $pages;
    }
}
