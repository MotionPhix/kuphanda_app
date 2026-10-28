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
 * Seeds the library catalogue owned by Kuphanda. Only the two Kuphanda-authored
 * guides have files; every other record is metadata until the library team
 * publishes a version. That mirrors production: students never upload content.
 */
final class LibrarySeeder extends Seeder
{
    public function run(): void
    {
        foreach ($this->subjects() as $subject) {
            Subject::query()->updateOrCreate(['id' => $subject['id']], $subject);
        }

        foreach ($this->documents() as $data) {
            $versions = $data['versions'] ?? [];
            unset($data['versions']);

            $document = Document::query()->updateOrCreate(['id' => $data['id']], $data);

            $latest = null;
            foreach ($versions as $version) {
                $latest = $this->publishVersion($document, $version);
            }

            $document->forceFill([
                'latest_version' => $latest?->version ?? 0,
                'content_updated_at' => $latest?->published_at,
            ])->save();
        }
    }

    /**
     * @param  array{version:int,file:string,notes?:string,days_ago:int}  $version
     */
    private function publishVersion(Document $document, array $version): DocumentVersion
    {
        $source = database_path('seeders/files/'.$version['file']);
        $contents = file_get_contents($source);
        $path = 'library/documents/'.$document->id.'/v'.$version['version'].'.pdf';

        Storage::disk('local')->put($path, $contents);

        return DocumentVersion::query()->updateOrCreate(
            [
                'document_id' => $document->id,
                'version' => $version['version'],
            ],
            [
                'disk' => 'local',
                'path' => $path,
                'file_name' => $version['file'],
                'mime_type' => 'application/pdf',
                'size_bytes' => strlen($contents),
                'page_count' => $version['page_count'],
                'checksum' => hash('sha256', $contents),
                'notes' => $version['notes'] ?? null,
                'published_at' => Carbon::now()->subDays($version['days_ago']),
            ]
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
                'description' => 'A short guide to finding papers, subscribing, downloading for offline reading and keeping notes.',
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
                'description' => 'A printable week plan with a 40-minute study block, marking routine and weekly review questions.',
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
                'id' => 'ref-msce-biology-2023-paper2',
                'subject_id' => 'biology',
                'title' => 'MSCE Biology 2023 — Paper 2 with worked solutions',
                'form' => 4,
                'kind' => 'pastPaper',
                'description' => 'Complete Paper 2 with structured answers and examiner-style commentary for every question.',
                'pages' => 24,
                'year' => 2023,
                'paper_number' => 2,
                'session' => 'November',
                'total_marks' => 100,
                'duration_minutes' => 150,
                'access_tier' => 'free',
                'author' => 'Kuphanda Library',
                'featured' => true,
                'tags' => ['worked solutions', 'paper 2'],
            ],
            [
                'id' => 'ref-jce-mathematics-toolkit',
                'subject_id' => 'mathematics',
                'title' => 'JCE Mathematics — full toolkit',
                'form' => 2,
                'kind' => 'notes',
                'description' => 'Every JCE topic in one workbook, with 300 practice problems and worked answers.',
                'pages' => 96,
                'access_tier' => 'free',
                'author' => 'T. Banda',
                'tags' => ['workbook', 'practice'],
            ],
            [
                'id' => 'ref-msce-chemistry-organic',
                'subject_id' => 'chemistry',
                'title' => 'MSCE Chemistry — Organic chemistry masterclass',
                'form' => 4,
                'kind' => 'guide',
                'description' => 'Alkanes to esters, IUPAC naming and every reaction pathway needed for Paper 2.',
                'pages' => 58,
                'access_tier' => 'weekly',
                'price_mwk' => 2500,
                'author' => 'Dr. C. Phiri',
                'tags' => ['organic chemistry'],
            ],
            [
                'id' => 'ref-msce-physics-mechanics',
                'subject_id' => 'physics',
                'title' => 'MSCE Physics — Mechanics workbook',
                'form' => 4,
                'kind' => 'notes',
                'description' => 'Vectors, motion, forces and momentum, with marking points called out.',
                'pages' => 72,
                'access_tier' => 'daily',
                'price_mwk' => 1500,
                'author' => 'E. Mwale',
                'tags' => ['mechanics'],
            ],
            [
                'id' => 'ref-chichewa-ndakatulo',
                'subject_id' => 'chichewa',
                'title' => 'Chichewa — Ndakatulo essay technique',
                'form' => 4,
                'kind' => 'guide',
                'description' => 'How to unpack any ndakatulo in under eight minutes, with three fully worked essays.',
                'pages' => 32,
                'access_tier' => 'free',
                'author' => 'M. Nyirenda',
                'language' => 'Chichewa',
                'featured' => true,
                'tags' => ['ndakatulo'],
            ],
            [
                'id' => 'notes-mathematics-f4',
                'subject_id' => 'mathematics',
                'title' => 'Mathematics — Form 4 study notes',
                'form' => 4,
                'kind' => 'notes',
                'description' => 'Form 4 mathematics organised term by term for the MSCE syllabus, with worked examples.',
                'pages' => 44,
                'access_tier' => 'free',
                'author' => 'Kuphanda Library',
                'tags' => ['notes', 'form 4'],
            ],
            [
                'id' => 'syllabus-biology',
                'subject_id' => 'biology',
                'title' => 'MSCE Biology syllabus',
                'form' => 4,
                'kind' => 'syllabus',
                'description' => 'The examinable syllabus: topics, learning outcomes and suggested time allocation.',
                'pages' => 20,
                'access_tier' => 'free',
                'author' => 'Malawi curriculum reference',
                'tags' => ['syllabus'],
            ],
            [
                'id' => 'guide-bio-genetics',
                'subject_id' => 'biology',
                'title' => 'Genetics — MSCE study guide',
                'form' => 4,
                'kind' => 'studyGuide',
                'description' => 'Mendelian inheritance, monohybrid crosses, sex linkage and mutation, with exam-style practice.',
                'pages' => 4,
                'access_tier' => 'free',
                'author' => 'Kuphanda Curriculum Team',
                'guide_id' => 'bio-genetics',
                'tags' => ['study guide'],
            ],
        ];
    }
}
