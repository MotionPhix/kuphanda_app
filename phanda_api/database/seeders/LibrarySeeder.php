<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Document;
use App\Models\DocumentVersion;
use App\Models\Subject;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;

/**
 * Seeds the library catalogue owned by Kuphanda.
 *
 * Every record this creates can be opened: a published PDF, a set of structured
 * blocks, or a guide whose sections ship inside the app. Nothing here is a
 * placeholder waiting for a file that does not exist, because the catalogue is
 * the product — a learner who taps a title and gets a dead button learns not to
 * trust the library.
 */
final class LibrarySeeder extends Seeder
{
    /**
     * Records that carried a title, a page count and a price but no content.
     * They are removed on every seed so an existing database is cleaned too.
     *
     * @var list<string>
     */
    private const RETIRED = [
        'ref-msce-biology-2023-paper2',
    ];

    public function run(): void
    {
        foreach ($this->subjects() as $subject) {
            Subject::query()->updateOrCreate(['id' => $subject['id']], $subject);
        }

        $this->retirePlaceholders();

        foreach ($this->documents() as $data) {
            $versions = $data['versions'] ?? [];
            $blocksFile = $data['blocks_file'] ?? null;
            unset($data['versions'], $data['blocks_file']);

            $document = Document::query()->updateOrCreate(['id' => $data['id']], $data);

            $latest = null;
            foreach ($versions as $version) {
                $latest = $this->publishVersion($document, $version);
            }

            if ($blocksFile !== null) {
                $this->attachBlocks($document, $blocksFile);
            }

            $document->forceFill([
                'latest_version' => $latest?->version ?? 0,
                'content_updated_at' => $latest?->published_at
                    ?? $document->content_updated_at
                    ?? Carbon::now(),
            ])->save();
        }

        $this->seedGuides();
    }

    /**
     * Adds the curriculum guides the app already carries.
     *
     * Their sections live in the app bundle, so the record needs no blocks and no
     * file: `guide_id` is enough for the reader to resolve the content. Without
     * these rows an online learner sees a smaller library than an offline one.
     *
     * The list is generated from `curriculum_seed.dart` by `tool/dump_guides.dart`
     * rather than retyped here, so the two catalogues cannot drift.
     */
    private function seedGuides(): void
    {
        $path = database_path('seeders/files/guides.json');
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('Guides skipped: guides.json is missing.');

            return;
        }

        /** @var array{guides?: array<int, array<string, mixed>>} $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        $created = 0;

        foreach ($json['guides'] ?? [] as $guide) {
            $id = is_string($guide['id'] ?? null) ? $guide['id'] : null;

            if ($id === null) {
                continue;
            }

            $documentId = 'guide-'.$id;

            // A guide that already has its own record — the authored genetics
            // blocks, for instance — keeps it; seeding must not replace richer
            // content with a pointer to the bundled sections.
            if (Document::query()->whereKey($documentId)->exists()) {
                continue;
            }

            $sections = array_slice((array) ($guide['sections'] ?? []), 0, 4);
            $blurb = (string) ($guide['blurb'] ?? '');

            Document::query()->create([
                'id' => $documentId,
                'subject_id' => $guide['subject_id'] ?? 'biology',
                'title' => ($guide['title'] ?? 'Study guide').' — MSCE study guide',
                'form' => 4,
                'kind' => 'studyGuide',
                'description' => trim($blurb.' Covers '.implode(', ', $sections).'.'),
                'pages' => max(1, (int) ($guide['pages'] ?? 1)),
                'access_tier' => 'free',
                'price_mwk' => 0,
                'author' => 'Kuphanda Curriculum Team',
                'language' => 'English',
                'guide_id' => $id,
                'is_published' => true,
                'content_updated_at' => Carbon::now(),
                'tags' => ['study guide'],
            ]);

            $created++;
        }

        $this->command?->info(sprintf('Added %d bundled guide(s) to the catalogue.', $created));
    }

    /**
     * Removes records that promised content but never carried any. They are
     * deleted, not merely unpublished: a learner who searches for "MSCE Biology
     * 2023" should not find a row whose only action is a dead button.
     *
     * A record somebody has already acted on — bought, marked offline, or set as
     * class work — is kept and unpublished instead, so no purchase or assignment
     * is silently destroyed.
     */
    private function retirePlaceholders(): void
    {
        foreach (self::RETIRED as $id) {
            $document = Document::query()->find($id);

            if ($document === null) {
                continue;
            }

            $inUse = $document->purchases()->exists()
                || $document->offlineMarks()->exists()
                || $document->assignments()->exists();

            if ($inUse) {
                $document->forceFill(['is_published' => false])->save();
                $this->command?->warn('Unpublished retired placeholder '.$id.' (it is in use).');

                continue;
            }

            $document->delete();
            $this->command?->info('Removed placeholder '.$id.'.');
        }
    }

    /** Attaches the structured content a reflowable document is read from. */
    private function attachBlocks(Document $document, string $file): void
    {
        $path = database_path('seeders/files/'.$file);
        $raw = @file_get_contents($path);

        if ($raw === false) {
            $this->command?->warn('No blocks attached to '.$document->id.': '.$file.' is missing.');

            return;
        }

        /** @var array<string, mixed> $json */
        $json = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        $blocks = $json['blocks'] ?? [];

        if (! is_array($blocks) || $blocks === []) {
            $this->command?->warn('No blocks attached to '.$document->id.': '.$file.' has none.');

            return;
        }

        $document->forceFill([
            'format' => $document->id === 'ref-msce-physics-mechanics' ? 'hybrid' : 'blocks',
            'blocks' => [
                'subtitle' => $json['subtitle'] ?? null,
                'blocks' => $blocks,
            ],
        ])->save();
    }

    /**
     * @param  array{version:int,file:string,notes?:string,days_ago:int}  $version
     */
    private function publishVersion(Document $document, array $version): DocumentVersion
    {
        $publisher = app(\App\Services\DocumentPublisher::class);
        $existing = $document->versions()
            ->where('version', $version['version'])
            ->first();

        if ($existing !== null) {
            if ($existing->media_id === null) {
                $publisher->importExisting($document, $existing);
            }

            return $existing->fresh();
        }

        return $publisher->publish(
            $document,
            database_path('seeders/files/'.$version['file']),
            $version['page_count'],
            $version['notes'] ?? null,
            $version['version'],
            Carbon::now()->subDays($version['days_ago']),
        );
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function subjects(): array
    {
        return [
            ['id' => 'mathematics', 'name' => 'Mathematics', 'short_name' => 'Maths', 'emoji' => '📐', 'color' => '#2F6B9A', 'forms' => [1, 2, 3, 4], 'sort_order' => 1, 'blurb' => 'Number, algebra, geometry, trigonometry and statistics.'],
            ['id' => 'biology', 'name' => 'Biology', 'short_name' => 'Biology', 'emoji' => '🧬', 'color' => '#2E7D4F', 'forms' => [3, 4], 'sort_order' => 2, 'blurb' => 'Cells, genetics, ecology and human systems for MSCE.'],
            ['id' => 'physical-science', 'name' => 'Physical Science', 'short_name' => 'Science', 'emoji' => '⚗️', 'color' => '#4B7A8A', 'forms' => [1, 2], 'sort_order' => 3, 'blurb' => 'Combined physics and chemistry for JCE.'],
            ['id' => 'chemistry', 'name' => 'Chemistry', 'short_name' => 'Chemistry', 'emoji' => '🧪', 'color' => '#8A5A2B', 'forms' => [3, 4], 'sort_order' => 4, 'blurb' => 'Atomic structure, moles, reactions and organic chemistry.'],
            ['id' => 'physics', 'name' => 'Physics', 'short_name' => 'Physics', 'emoji' => '🔭', 'color' => '#4C5B9A', 'forms' => [3, 4], 'sort_order' => 5, 'blurb' => 'Mechanics, waves, electricity and modern physics.'],
            ['id' => 'english', 'name' => 'English', 'short_name' => 'English', 'emoji' => '📖', 'color' => '#8C3A52', 'forms' => [1, 2, 3, 4], 'sort_order' => 6, 'blurb' => 'Comprehension, summary, composition and literature.'],
            ['id' => 'chichewa', 'name' => 'Chichewa', 'short_name' => 'Chichewa', 'emoji' => '🗣️', 'color' => '#9A5B2F', 'forms' => [1, 2, 3, 4], 'sort_order' => 7, 'blurb' => 'Galamala, ndakatulo, nkhani ndi mawu a m’mabuku.'],
            ['id' => 'geography', 'name' => 'Geography', 'short_name' => 'Geography', 'emoji' => '🌍', 'color' => '#2F7A6B', 'forms' => [1, 2, 3, 4], 'sort_order' => 8, 'blurb' => 'Physical and human geography, map work and Malawi case studies.'],
            ['id' => 'history', 'name' => 'History', 'short_name' => 'History', 'emoji' => '🏛️', 'color' => '#7A5B3A', 'forms' => [1, 2, 3, 4], 'sort_order' => 9, 'blurb' => 'Malawian, African and world history.'],
            ['id' => 'agriculture', 'name' => 'Agriculture', 'short_name' => 'Agriculture', 'emoji' => '🌾', 'color' => '#5C7A2F', 'forms' => [1, 2, 3, 4], 'sort_order' => 10, 'blurb' => 'Crop and livestock production for Malawian schools.'],
            ['id' => 'computer-studies', 'name' => 'Computer Studies', 'short_name' => 'Computing', 'emoji' => '💻', 'color' => '#3F6E8C', 'forms' => [3, 4], 'sort_order' => 11, 'blurb' => 'Computer systems, data representation and networks.'],
            ['id' => 'business-studies', 'name' => 'Business Studies', 'short_name' => 'Business', 'emoji' => '📊', 'color' => '#7A6B2F', 'forms' => [3, 4], 'sort_order' => 12, 'blurb' => 'Business ownership, finance and commerce.'],
            ['id' => 'religious-studies', 'name' => 'Religious Studies', 'short_name' => 'RE', 'emoji' => '🕊️', 'color' => '#6A5B8C', 'forms' => [1, 2, 3, 4], 'sort_order' => 13, 'blurb' => 'Christianity and Islam in Malawi.'],
            ['id' => 'social-studies', 'name' => 'Social Studies', 'short_name' => 'Social', 'emoji' => '🌐', 'color' => '#8C6A3A', 'forms' => [1, 2], 'sort_order' => 14, 'blurb' => 'Civics, culture and community life for JCE.'],
        ];
    }

    /**
     * The catalogue Kuphanda owns and can actually serve.
     *
     * Every entry here is readable: it either carries structured blocks, ships a
     * published PDF, or is a guide whose sections ship inside the app. A record
     * without content is not a catalogue entry — it is a dead button, and the
     * readiness audit refuses to publish one.
     *
     * @return array<int, array<string, mixed>>
     */
    private function documents(): array
    {
        return [
            [
                'id' => 'sample-howto',
                'subject_id' => 'english',
                'title' => 'How to use Kuphanda',
                'form' => 1,
                'kind' => 'guide',
                'description' => 'Finding papers, subscribing, downloading for offline reading and keeping notes — the four things a new learner needs in the first week.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'Kuphanda',
                'language' => 'English',
                'tags' => ['getting started'],
                'featured' => true,
                'is_published' => true,
                'versions' => [
                    ['version' => 1, 'file' => 'kuphanda-quick-start.pdf', 'page_count' => 2, 'days_ago' => 30, 'notes' => 'First edition'],
                    ['version' => 2, 'file' => 'kuphanda-quick-start-v2.pdf', 'page_count' => 4, 'days_ago' => 0, 'notes' => 'Second edition adds the weekly planner'],
                ],
            ],
            [
                'id' => 'sample-planner',
                'subject_id' => 'mathematics',
                'title' => 'Weekly study planner',
                'form' => 4,
                'kind' => 'other',
                'description' => 'A printable week plan built around a 40-minute study block, with a marking routine and a weekly review page.',
                'pages' => 2,
                'access_tier' => 'free',
                'author' => 'Kuphanda',
                'tags' => ['planner', 'revision'],
                'is_published' => true,
                'versions' => [
                    ['version' => 1, 'file' => 'weekly-study-planner.pdf', 'page_count' => 2, 'days_ago' => 20],
                ],
            ],
            [
                'id' => 'ref-msce-physics-mechanics',
                'subject_id' => 'physics',
                'form' => 4,
                'kind' => 'notes',
                'title' => 'Mechanics: motion, force and momentum',
                'description' => 'Motion graphs, worked examples on acceleration and a momentum collision, with the marking points called out. Structured for the reflowable reader.',
                'pages' => 3,
                'access_tier' => 'daily',
                'price_mwk' => 1500,
                'author' => 'E. Mwale',
                'language' => 'English',
                'blocks_file' => 'blocks-mechanics.json',
                'tags' => ['mechanics', 'workbook'],
            ],
            [
                'id' => 'guide-bio-genetics',
                'subject_id' => 'biology',
                'form' => 4,
                'kind' => 'studyGuide',
                'title' => 'Genetics: inheritance, DNA and variation',
                'description' => 'Alleles and genotypes, monohybrid crosses with worked Punnett squares, DNA replication and the two kinds of variation. Written for MSCE Paper 2.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'Kuphanda Curriculum Team',
                'language' => 'English',
                'blocks_file' => 'blocks-biology-genetics.json',
                'featured' => true,
                'tags' => ['genetics', 'paper 2'],
            ],
            [
                'id' => 'ref-msce-chemistry-organic',
                'subject_id' => 'chemistry',
                'form' => 4,
                'kind' => 'guide',
                'title' => 'Organic chemistry: from alkanes to esters',
                'description' => 'The four homologous series, IUPAC naming, the reactions that carry marks and the test for unsaturation, with a worked exam question.',
                'pages' => 4,
                'access_tier' => 'weekly',
                'price_mwk' => 2500,
                'author' => 'Dr. C. Phiri',
                'language' => 'English',
                'blocks_file' => 'blocks-chemistry-organic.json',
                'tags' => ['organic chemistry', 'paper 2'],
            ],
            [
                'id' => 'notes-mathematics-f4',
                'subject_id' => 'mathematics',
                'form' => 4,
                'kind' => 'notes',
                'title' => 'Form 4 mathematics: functions, circles and statistics',
                'description' => 'Completing the square, the circle theorems with the reasons to quote, and estimating a mean from grouped data. Worked examples throughout.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'Kuphanda Library',
                'language' => 'English',
                'blocks_file' => 'blocks-mathematics-f4.json',
                'tags' => ['notes', 'form 4'],
            ],
            [
                'id' => 'ref-chichewa-ndakatulo',
                'subject_id' => 'chichewa',
                'form' => 4,
                'kind' => 'guide',
                'title' => 'Ndakatulo: mfundo, kapangidwe ndi kawerengedwe',
                'description' => 'Momwe tingawerenge ndakatulo mwachangu: mfundo yaikulu, fanizo, chifaniziro, ndi mmene tingayankhire mafunso a MSCE.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'M. Nyirenda',
                'language' => 'Chichewa',
                'blocks_file' => 'blocks-chichewa-ndakatulo.json',
                'featured' => true,
                'tags' => ['ndakatulo', 'chichewa'],
            ],
            [
                'id' => 'ref-msce-geography-mapwork',
                'subject_id' => 'geography',
                'form' => 4,
                'kind' => 'notes',
                'title' => 'Map work: scale, bearings and relief',
                'description' => 'Scale conversions, three-figure bearings and back bearings, reading contours, and drawing a cross-section that can actually be marked.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'Kuphanda Library',
                'language' => 'English',
                'blocks_file' => 'blocks-geography-mapwork.json',
                'tags' => ['map work', 'paper 2'],
            ],
            [
                'id' => 'ref-agriculture-livestock',
                'subject_id' => 'agriculture',
                'form' => 4,
                'kind' => 'guide',
                'title' => 'Livestock production: housing, feeding and health',
                'description' => 'Cattle, goats and poultry on a smallholding: housing dimensions, roughage and concentrate, and the five diseases that repeat in exams.',
                'pages' => 5,
                'access_tier' => 'weekly',
                'price_mwk' => 2000,
                'author' => 'R. Kachale',
                'language' => 'English',
                'blocks_file' => 'blocks-agriculture-livestock.json',
                'tags' => ['livestock', 'disease'],
            ],
            [
                'id' => 'ref-jce-mathematics-toolkit',
                'subject_id' => 'mathematics',
                'form' => 2,
                'kind' => 'notes',
                'title' => 'JCE mathematics: number, algebra and shape',
                'description' => 'Fractions to percentages, expanding and solving, and the area and volume formulas — the three areas that decide a JCE grade, with worked examples.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'T. Banda',
                'language' => 'English',
                'blocks_file' => 'blocks-jce-mathematics.json',
                'tags' => ['workbook', 'practice'],
            ],
            [
                'id' => 'syllabus-biology',
                'subject_id' => 'biology',
                'form' => 4,
                'kind' => 'syllabus',
                'title' => 'MSCE Biology: examinable topics and how they are weighted',
                'description' => 'A revision map of the examinable topics with the paper each one appears in, plus an eight-week plan. A checklist, not a copy of the syllabus.',
                'pages' => 5,
                'access_tier' => 'free',
                'author' => 'Kuphanda Curriculum Team',
                'language' => 'English',
                'blocks_file' => 'blocks-biology-syllabus.json',
                'tags' => ['syllabus', 'revision'],
            ],
            [
                'id' => 'ref-msce-biology-practice-p2',
                'subject_id' => 'biology',
                'form' => 4,
                'kind' => 'pastPaper',
                'title' => 'Biology Paper 2 practice paper',
                'description' => 'A Kuphanda mock paper: 100 marks over six structured questions on osmosis, photosynthesis, genetics, populations and human systems.',
                'pages' => 5,
                'year' => 2026,
                'paper_number' => 2,
                'session' => 'November',
                'total_marks' => 100,
                'duration_minutes' => 120,
                'access_tier' => 'free',
                'author' => 'Kuphanda Curriculum Team',
                'language' => 'English',
                'blocks_file' => 'blocks-biology-practice-paper.json',
                'tags' => ['practice paper', 'paper 2'],
            ],
        ];
    }
}
