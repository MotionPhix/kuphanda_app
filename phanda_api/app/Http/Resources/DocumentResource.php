<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Document;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Document
 */
final class DocumentResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'subject_id' => $this->subject_id,
            'subject' => new SubjectResource($this->whenLoaded('subject')),
            'form' => $this->form,
            'kind' => $this->kind,
            'description' => $this->description,
            'pages' => $this->pages,
            'year' => $this->year,
            'paper_number' => $this->paper_number,
            'session' => $this->session,
            'total_marks' => $this->total_marks,
            'duration_minutes' => $this->duration_minutes,
            'access_tier' => $this->access_tier->value,
            'price_mwk' => $this->price_mwk,
            'is_entitled' => $request->user() === null
                ? false
                : app(\App\Services\EntitlementService::class)->canAccess($request->user(), $this->resource),
            'author' => $this->author,
            'publisher' => $this->publisher,
            'language' => $this->language,
            'tags' => $this->tags ?? [],
            'guide_id' => $this->guide_id,
            'featured' => $this->featured,
            'latest_version' => $this->latest_version,
            'has_file' => $this->latest_version > 0,
            'current_version' => new DocumentVersionResource($this->whenLoaded('currentVersion')),
            'content_updated_at' => $this->content_updated_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
