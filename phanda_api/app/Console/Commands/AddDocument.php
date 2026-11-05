<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Document;
use App\Models\Subject;
use App\Services\DocumentPublisher;
use App\Services\Library\DocumentPublisher as ReadinessPublisher;
use Illuminate\Console\Command;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Adds a new document to the catalogue from a PDF.
 *
 * `library:publish` can only add a version to a document that already exists, so
 * growing the library meant editing a seeder and deploying code — a strange
 * requirement for the team that owns the content. This creates the record and its
 * first version in one step, then hands the result to the same publisher the
 * seeder uses, so readiness and marks are checked exactly as before.
 */
final class AddDocument extends Command
{
    protected $signature = 'library:add
        {file : Path to the PDF on this machine}
        {--id= : Stable document id (defaults to a slug of the title)}
        {--title= : Title shown to learners}
        {--subject= : Subject id, e.g. biology}
        {--form=4 : Form 1 to 4}
        {--kind=notes : guide, notes, pastPaper, studyGuide, syllabus or other}
        {--tier=free : free, daily or weekly}
        {--price= : Price in MWK when the tier is paid}
        {--author= : Author shown on the document}
        {--language=English : Language of the content}
        {--description= : One or two sentences shown on the card}
        {--pages= : Page count (estimated from the PDF when omitted)}';

    protected $description = 'Create a catalogue document from a PDF and publish its first version';

    private const MAX_BYTES = 50 * 1024 * 1024;

    private const KINDS = ['guide', 'notes', 'pastPaper', 'studyGuide', 'syllabus', 'other'];

    private const TIERS = ['free', 'daily', 'weekly'];

    public function handle(): int
    {
        $title = trim((string) $this->option('title'));
        $subjectId = (string) $this->option('subject');
        $form = (int) $this->option('form');
        $kind = (string) $this->option('kind');
        $tier = (string) $this->option('tier');

        if ($title === '') {
            $this->error('--title is required: the catalogue cannot show an untitled document.');

            return self::FAILURE;
        }

        if (! Subject::query()->whereKey($subjectId)->exists()) {
            $this->error(sprintf('No subject "%s". Run `php artisan db:seed --class=SubjectSeeder` or pick an existing id.', $subjectId));

            return self::FAILURE;
        }

        if ($form < 1 || $form > 4) {
            $this->error('--form must be 1, 2, 3 or 4.');

            return self::FAILURE;
        }

        if (! in_array($kind, self::KINDS, true)) {
            $this->error('--kind must be one of: '.implode(', ', self::KINDS).'.');

            return self::FAILURE;
        }

        if (! in_array($tier, self::TIERS, true)) {
            $this->error('--tier must be one of: '.implode(', ', self::TIERS).'.');

            return self::FAILURE;
        }

        $price = $this->option('price');
        if ($tier !== 'free' && ($price === null || ! ctype_digit((string) $price) || (int) $price < 1)) {
            $this->error('A paid tier needs --price in whole MWK.');

            return self::FAILURE;
        }

        $id = (string) ($this->option('id') ?: Str::slug($title));

        if (Document::query()->whereKey($id)->exists()) {
            $this->error(sprintf('A document with id "%s" already exists. Use library:publish to release a new version.', $id));

            return self::FAILURE;
        }

        $path = (string) $this->argument('file');
        $pageCount = $this->inspectFile($path);

        if ($pageCount === null) {
            return self::FAILURE;
        }

        $pagesOption = $this->option('pages');

        if ($pagesOption !== null) {
            if (! ctype_digit((string) $pagesOption) || (int) $pagesOption < 1) {
                $this->error('--pages must be a positive integer.');

                return self::FAILURE;
            }

            $pageCount = (int) $pagesOption;
        }

        $document = Document::query()->create([
            'id' => $id,
            'subject_id' => $subjectId,
            'title' => $title,
            'form' => $form,
            'kind' => $kind,
            'description' => (string) ($this->option('description') ?? ''),
            'pages' => $pageCount,
            'access_tier' => $tier,
            'price_mwk' => $tier === 'free' ? 0 : (int) $price,
            'author' => (string) ($this->option('author') ?? 'Kuphanda'),
            'language' => (string) ($this->option('language') ?? 'English'),
            'is_published' => false,
            'latest_version' => 0,
            'tags' => [],
        ]);

        try {
            $version = app(DocumentPublisher::class)->publish(
                $document,
                $path,
                $pageCount,
                'First upload',
            );

            app(ReadinessPublisher::class)->publish($document);
        } catch (Throwable $exception) {
            // A half-made record would sit in the catalogue pointing at nothing;
            // remove the row rather than leave the next person to find it.
            $document->delete();
            report($exception);
            $this->error('Adding the document failed: '.$exception->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Added %s — "%s" (%s, Form %d, %s), v%d, %d pages.',
            $document->id,
            $document->title,
            $subjectId,
            $form,
            $tier,
            $version->version,
            $version->page_count,
        ));
        $this->line('Check it with: php artisan library:sync --prune  (or curl /api/v1/health)');

        return self::SUCCESS;
    }

    /** Checks the file is a usable PDF and estimates its page count. */
    private function inspectFile(string $path): ?int
    {
        if (! is_file($path) || ! is_readable($path)) {
            $this->error('The file does not exist or cannot be read.');

            return null;
        }

        $size = (int) filesize($path);

        if ($size === 0) {
            $this->error('The file is empty.');

            return null;
        }

        if ($size > self::MAX_BYTES) {
            $this->error('The file is larger than the 50 MB limit.');

            return null;
        }

        $contents = file_get_contents($path);

        if ($contents === false || ! str_starts_with($contents, '%PDF')) {
            $this->error('That file is not a PDF.');

            return null;
        }

        $count = preg_match_all('/\/Type\s*\/Page[^s]/', $contents);

        return is_int($count) && $count > 0 ? $count : 1;
    }
}
