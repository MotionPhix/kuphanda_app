<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Models\Document;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class DownloadController extends ApiController
{
    public function __invoke(Request $request, Document $document): StreamedResponse|\Illuminate\Http\JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if (! $document->is_published) {
            return $this->notFound('Document not found.');
        }

        if (! app(\App\Services\EntitlementService::class)->canAccess($user, $document)) {
            return $this->forbidden('Subscribe or buy this document before downloading it.');
        }

        $marked = $document->offlineMarks()
            ->where('user_id', $user->id)
            ->exists();

        if (! $marked) {
            return $this->error(
                'Mark this document for offline reading before downloading it.',
                409
            );
        }

        $version = $document->currentVersion;

        if ($version === null) {
            return $this->notFound('This document has no file available.');
        }

        // New versions are stored by Spatie Media Library; older rows fall back
        // to the plain disk path until they are backfilled.
        if ($version->media !== null) {
            $stream = $version->media->stream();
        } else {
            $disk = Storage::disk($version->disk);

            if (! $disk->exists($version->path)) {
                return $this->notFound('The stored file is missing. Contact the library administrator.');
            }

            $stream = $disk->readStream($version->path);
        }

        if ($stream === false) {
            return $this->error('The stored file could not be read.', 500);
        }

        $response = response()->streamDownload(function () use ($stream): void {
            fpassthru($stream);
            if (is_resource($stream)) {
                fclose($stream);
            }
        }, $version->file_name, [
            'Content-Type' => $version->mime_type,
            'Content-Length' => (string) $version->size_bytes,
            'X-Document-Version' => (string) $version->version,
            'X-Document-Checksum' => $version->checksum,
            'Cache-Control' => 'private, max-age=0, must-revalidate',
        ]);

        $response->setEtag($version->checksum);
        $response->setLastModified($version->published_at);

        // Supports If-None-Match / If-Modified-Since so a client can cheaply
        // confirm that its stored copy is still the current one.
        if ($response->isNotModified($request)) {
            return $response;
        }

        return $response;
    }
}
