<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Subject;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Subject
 */
final class SubjectResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'short_name' => $this->short_name,
            'emoji' => $this->emoji,
            'color' => $this->color,
            'forms' => $this->forms,
            'blurb' => $this->blurb,
        ];
    }
}
