<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\StoreDocumentVersionRequest;
use App\Http\Resources\DocumentVersionResource;
use App\Models\Document;
use App\Services\DocumentPublisher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

final class StaffDocumentController extends ApiController
{
    public function index(): JsonResponse
    {
        $documents = Document::query()
            ->with(['subject', 'currentVersion'])
            ->orderBy('title')
            ->get()
            ->map(fn (Document $document): array => $this->summary($document))
            ->values();

        return $this->success($documents);
    }

    public function versions(Document $document): JsonResponse
    {
        $versions = $document->versions()
            ->orderByDesc('version')
            ->get()
            ->map(fn ($version): array => [
                'number' => $version->version,
                'file_name' => $version->file_name,
                'size_bytes' => $version->size_bytes,
                'page_count' => $version->page_count,
                'checksum' => $version->checksum,
                'media_id' => $version->media_id,
                'notes' => $version->notes,
                'published_at' => $version->published_at?->toIso8601String(),
            ]);

        return $this->success([
            'document' => $this->summary($document->load('subject', 'currentVersion')),
            'versions' => $versions,
        ]);
    }

    public function storeVersion(
        StoreDocumentVersionRequest $request,
        Document $document,
        DocumentPublisher $publisher,
    ): JsonResponse {
        $file = $request->file('file');

        try {
            $version = $publisher->publish(
                $document,
                $file->getRealPath(),
                (int) $request->integer('pages'),
                $request->input('notes'),
            );
        } catch (RuntimeException $exception) {
            return $this->error($exception->getMessage(), 422);
        }

        return $this->created(
            new DocumentVersionResource($version),
            'Version '.$version->version.' published.'
        );
    }

    public function updatePublication(Request $request, Document $document): JsonResponse
    {
        $validated = $request->validate([
            'is_published' => ['required', 'boolean'],
        ]);

        $document->forceFill([
            'is_published' => (bool) $validated['is_published'],
            'content_updated_at' => now(),
        ])->save();

        return $this->success(
            $this->summary($document->fresh(['subject', 'currentVersion'])),
            $document->is_published ? 'Document published.' : 'Document withdrawn.'
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function summary(Document $document): array
    {
        return [
            'id' => $document->id,
            'title' => $document->title,
            'subject' => $document->subject?->name,
            'form' => $document->form,
            'kind' => $document->kind,
            'is_published' => (bool) $document->is_published,
            'latest_version' => (int) $document->latest_version,
            'pages' => (int) $document->pages,
            'price_mwk' => (int) $document->price_mwk,
            'version_count' => $document->versions()->count(),
            'media_count' => $document->getMedia('files')->count(),
            'current_version' => $document->currentVersion === null
                ? null
                : new DocumentVersionResource($document->currentVersion),
        ];
    }
}
