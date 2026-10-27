<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\DocumentVersion;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin DocumentVersion
 */
final class DocumentVersionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'number' => $this->version,
            'file_name' => $this->file_name,
            'mime_type' => $this->mime_type,
            'size_bytes' => $this->size_bytes,
            'page_count' => $this->page_count,
            'checksum' => $this->checksum,
            'published_at' => $this->published_at->toIso8601String(),
        ];
    }
}
