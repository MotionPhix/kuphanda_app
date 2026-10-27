<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\AckDownloadRequest;
use App\Http\Requests\Api\V1\StoreOfflineRequest;
use App\Http\Requests\Api\V1\SyncLibraryRequest;
use App\Http\Resources\OfflineItemResource;
use App\Models\Document;
use App\Models\OfflineDocument;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class OfflineLibraryController extends ApiController
{
    private const RELATIONS = ['document.subject', 'document.currentVersion'];

    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $marks = OfflineDocument::query()
            ->where('user_id', $user->id)
            ->with(self::RELATIONS)
            ->orderByDesc('marked_at')
            ->get();

        return $this->success(OfflineItemResource::collection($marks));
    }

    public function store(StoreOfflineRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Document $document */
        $document = Document::query()
            ->published()
            ->with(['subject', 'currentVersion'])
            ->findOrFail((string) $request->validated('document_id'));

        if (! app(\App\Services\EntitlementService::class)->canAccess($user, $document)) {
            return $this->forbidden('Subscribe or buy this document before saving it offline.');
        }

        if ($document->currentVersion === null) {
            return $this->error('This document has no file available for download yet.', 409);
        }

        $mark = OfflineDocument::withTrashed()->firstOrNew([
            'user_id' => $user->id,
            'document_id' => $document->id,
        ]);

        if ($mark->trashed()) {
            $mark->restore();
        }

        $mark->marked_at = now();
        $mark->save();
        $mark->load(self::RELATIONS);

        return $this->created(
            new OfflineItemResource($mark),
            'Document marked for offline reading.'
        );
    }

    public function destroy(Request $request, Document $document): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $mark = OfflineDocument::query()
            ->where('user_id', $user->id)
            ->where('document_id', $document->id)
            ->first();

        if ($mark === null) {
            return $this->notFound('This document is not marked for offline reading.');
        }

        // Touch first so the tombstone carries a sync-visible timestamp.
        $mark->touch();
        $mark->delete();

        return $this->success(message: 'Document removed from offline reading.');
    }

    public function ack(AckDownloadRequest $request, Document $document): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $mark = OfflineDocument::query()
            ->where('user_id', $user->id)
            ->where('document_id', $document->id)
            ->first();

        if ($mark === null) {
            return $this->notFound('This document is not marked for offline reading.');
        }

        $version = (int) $request->validated('version');

        $exists = $document->versions()->where('version', $version)->exists();
        if (! $exists) {
            return $this->error('That version of the document does not exist.', 422);
        }

        $mark->downloaded_version = $version;
        $mark->last_synced_at = now();
        $mark->save();
        $mark->load(self::RELATIONS);

        return $this->success(new OfflineItemResource($mark), 'Download recorded.');
    }

    public function sync(SyncLibraryRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $since = $request->date('since');

        $marks = OfflineDocument::query()
            ->where('user_id', $user->id)
            ->with(self::RELATIONS)
            ->get();

        $changed = $marks->filter(function (OfflineDocument $mark) use ($since): bool {
            if (! $since instanceof \Illuminate\Support\Carbon) {
                return true;
            }

            $document = $mark->document;
            $currentVersion = $document?->currentVersion;

            return $mark->updated_at?->greaterThan($since)
                || $document?->content_updated_at?->greaterThan($since)
                || ($currentVersion !== null && $mark->downloaded_version !== $currentVersion->version);
        })->values();

        $removed = OfflineDocument::onlyTrashed()
            ->where('user_id', $user->id)
            ->when($since instanceof \Illuminate\Support\Carbon, fn ($query) => $query->where('updated_at', '>', $since))
            ->pluck('document_id')
            ->values();

        return $this->success([
            'server_time' => now()->toIso8601String(),
            'since' => $since?->toIso8601String(),
            'documents' => OfflineItemResource::collection($changed),
            'removed' => $removed,
        ]);
    }
}
