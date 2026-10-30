<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Classroom;
use App\Models\ClassroomAssignment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Classroom */
final class ClassroomResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'code' => $this->code,
            'form' => $this->form,
            'subject_id' => $this->subject_id,
            'teacher_name' => $this->teacher?->name,
            'created_at' => $this->created_at?->toIso8601String(),
            'member_count' => $this->members_count ?? $this->members()->count(),
            'assignments' => $this->assignments->map(fn (ClassroomAssignment $assignment): array => [
                'id' => $assignment->id,
                'document_id' => $assignment->document_id,
                'title' => $assignment->document?->title,
                'due_date' => $assignment->due_date?->toDateString(),
                'created_at' => $assignment->created_at?->toIso8601String(),
            ])->all(),
        ];
    }
}
