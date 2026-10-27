<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\DocumentResource;
use App\Http\Resources\SubjectResource;
use App\Models\Document;
use App\Models\Subject;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class CatalogController extends ApiController
{
    public function subjects(): JsonResponse
    {
        return $this->success(
            SubjectResource::collection(Subject::query()->orderBy('sort_order')->orderBy('name')->get())
        );
    }

    public function documents(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:120'],
            'subject' => ['nullable', 'string', 'max:64'],
            'form' => ['nullable', 'integer', 'between:1,4'],
            'kind' => ['nullable', 'string', 'max:32'],
            'updated_since' => ['nullable', 'date'],
            'per_page' => ['nullable', 'integer', 'between:1,100'],
        ]);

        $query = Document::query()
            ->published()
            ->with(['subject', 'currentVersion'])
            ->orderByDesc('featured')
            ->orderByDesc('content_updated_at')
            ->orderBy('title');

        if (! empty($validated['q'])) {
            $term = '%'.$validated['q'].'%';
            $query->where(function ($builder) use ($term): void {
                $builder->where('title', 'like', $term)
                    ->orWhere('description', 'like', $term)
                    ->orWhere('author', 'like', $term);
            });
        }

        if (! empty($validated['subject'])) {
            $query->where('subject_id', $validated['subject']);
        }

        if (! empty($validated['form'])) {
            $query->where('form', (int) $validated['form']);
        }

        if (! empty($validated['kind'])) {
            $query->where('kind', $validated['kind']);
        }

        if (! empty($validated['updated_since'])) {
            $query->where('content_updated_at', '>=', $validated['updated_since']);
        }

        $documents = $query->paginate((int) ($validated['per_page'] ?? 50))->withQueryString();

        return $this->success(DocumentResource::collection($documents));
    }

    public function show(Document $document): JsonResponse
    {
        if (! $document->is_published) {
            return $this->notFound('Document not found');
        }

        return $this->success(
            new DocumentResource($document->load(['subject', 'currentVersion']))
        );
    }
}
