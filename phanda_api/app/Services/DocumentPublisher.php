<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Document;
use App\Models\DocumentVersion;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;
use Spatie\MediaLibrary\MediaCollections\Models\Media;

/**
 * The single place that turns a PDF on disk into a published version.
 *
 * Spatie Media Library owns the bytes (disk, file name, mime type, size); the
 * document_versions row keeps the version number, checksum and page count the
 * sync API exposes. The media item id links the two.
 */
final class DocumentPublisher
{
    public function publish(
        Document $document,
        string $sourcePath,
        int $pageCount,
        ?string $notes = null,
        ?int $version = null,
        ?Carbon $publishedAt = null,
    ): DocumentVersion {
        if (! is_file($sourcePath)) {
            throw new RuntimeException('The source file does not exist.');
        }

        $next = $version ?? ((int) $document->versions()->max('version')) + 1;

        if ($document->versions()->where('version', $next)->exists()) {
            throw new RuntimeException("Version {$next} already exists for this document.");
        }

        return DB::transaction(function () use ($document, $sourcePath, $pageCount, $notes, $next, $publishedAt): DocumentVersion {
            /** @var Media $media */
            $media = $document
                ->addMedia($sourcePath)
                ->preservingOriginal()
                ->usingFileName(Str::slug($document->id).'-v'.$next.'.pdf')
                ->withCustomProperties(['version' => $next])
                ->toMediaCollection('files');

            $release = $publishedAt ?? now();

            $version = $document->versions()->create([
                'version' => $next,
                'disk' => $media->disk,
                'path' => $media->id.'/'.$media->file_name,
                'file_name' => $media->file_name,
                'mime_type' => $media->mime_type,
                'size_bytes' => $media->size,
                'page_count' => max(1, $pageCount),
                'checksum' => hash_file('sha256', $media->getPath()),
                'media_id' => $media->id,
                'notes' => $notes,
                'published_at' => $release,
            ]);

            $document->forceFill([
                'latest_version' => $next,
                'content_updated_at' => $release,
                'is_published' => true,
                'pages' => max(1, $pageCount),
            ])->save();

            return $version;
        });
    }

    /**
     * Moves a pre-Media-Library version into the media table without changing
     * its version number or checksum.
     */
    public function importExisting(Document $document, DocumentVersion $version): DocumentVersion
    {
        if ($version->media_id !== null) {
            return $version;
        }

        /** @var Media $media */
        $media = $document
            ->addMediaFromDisk($version->path, $version->disk)
            ->preservingOriginal()
            ->usingFileName($version->file_name)
            ->withCustomProperties(['version' => $version->version])
            ->toMediaCollection('files');

        $version->forceFill([
            'media_id' => $media->id,
            'disk' => $media->disk,
            'path' => $media->id.'/'.$media->file_name,
            'file_name' => $media->file_name,
            'mime_type' => $media->mime_type,
            'size_bytes' => $media->size,
        ])->save();

        return $version;
    }
}
