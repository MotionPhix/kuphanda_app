<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\OfflineDocument;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One learner's offline mark, with the metadata needed to decide whether the
 * stored file is still current.
 *
 * @mixin OfflineDocument
 */
final class OfflineItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $document = $this->whenLoaded('document');
        $currentVersion = $document instanceof \App\Models\Document && $document->relationLoaded('currentVersion')
            ? $document->currentVersion
            : null;

        $user = $request->user();

        return [
            'document' => new DocumentResource($this->whenLoaded('document')),
            'document_id' => $this->document_id,
            'price_mwk' => $document instanceof \App\Models\Document ? $document->price_mwk : 0,
            'is_entitled' => $user !== null && $document instanceof \App\Models\Document
                ? app(\App\Services\EntitlementService::class)->canAccess($user, $document)
                : false,
            'current_version' => $currentVersion === null
                ? null
                : new DocumentVersionResource($currentVersion),
            'downloaded_version' => $this->downloaded_version,
            'update_available' => $currentVersion !== null
                && $this->downloaded_version !== null
                && $this->downloaded_version < $currentVersion->version,
            'download_url' => route('api.v1.library.download', ['document' => $this->document_id]),
            'marked_at' => $this->marked_at->toIso8601String(),
            'last_synced_at' => $this->last_synced_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
