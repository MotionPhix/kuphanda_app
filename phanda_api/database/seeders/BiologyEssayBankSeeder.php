<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Document;
use Illuminate\Database\Seeder;

/**
 * Seeds the MScE Biology essay bank: 60 essay questions with model answers,
 * grouped into the 15 topics the source document covers.
 *
 * The questions and answers are transcribed from a typed question bank, not
 * written by Kuphanda, so `author` names the school rather than us and no year
 * or paper number is claimed — the bank is a revision resource, not a paper that
 * an examination board set. Nine questions carry no answer in the source; they
 * stay as question cards, because a learner planning an answer is still studying.
 */
final class BiologyEssayBankSeeder extends Seeder
{
    private const ID = 'ref-biology-essay-bank';

    private const FILE = 'blocks-biology-essay-bank.json';

    public function run(): void
    {
        $path = database_path('seeders/files/'.self::FILE);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Biology bank skipped: '.self::FILE.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);

        /** @var list<array<string, mixed>> $blocks */
        $blocks = is_array($json['blocks'] ?? null) ? $json['blocks'] : [];

        $pages = 1;
        foreach ($blocks as $block) {
            $page = $block['page'] ?? null;
            if (is_int($page) && $page > $pages) {
                $pages = $page;
            }
        }

        Document::query()->updateOrCreate(
            ['id' => self::ID],
            [
                'subject_id' => 'biology',
                'title' => $json['title'] ?? 'Biology essay questions with model answers',
                'form' => 4,
                'kind' => 'notes',
                'format' => 'blocks',
                'blocks' => [
                    'subtitle' => $json['subtitle'] ?? null,
                    'blocks' => $blocks,
                ],
                'description' => 'MSCE Biology essay questions with model answers, grouped by topic. '
                    .'Open a card to plan your own answer, then reveal the model answer to check it.',
                'pages' => $pages,
                'access_tier' => 'free',
                'price_mwk' => 0,
                'author' => 'Target Private Secondary School',
                'language' => 'English',
                'is_published' => true,
            ],
        );

        $this->command?->info('Seeded '.self::ID.' ('.$pages.' pages, '.count($blocks).' blocks).');
    }
}
