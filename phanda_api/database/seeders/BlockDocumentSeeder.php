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

    public function run(): void
    {
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
}
