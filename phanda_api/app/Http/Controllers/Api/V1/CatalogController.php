<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\DocumentResource;
use App\Http\Resources\SubjectResource;
use App\Models\Document;
use App\Models\Subject;
use App\Services\EntitlementService;
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
            ->readable()
            ->with(['subject', 'currentVersion'])
            ->orderByDesc('featured')
            ->orderByDesc('content_updated_at')
            ->orderBy('title');

        if (! empty($validated['q'])) {
            $term = '%'.$validated['q'].'%';
            // Search has to answer the question a learner actually asks. "Show me
            // the chemistry papers" used to match nothing unless the word happened
            // to be in a title: subject, tags and the exam year are how the
            // catalogue is organised, so they are searchable too. The app's
            // offline search already worked this way, which made the online one
            // feel broken by comparison.
            $query->where(function ($builder) use ($term, $validated): void {
                $builder->where('title', 'like', $term)
                    ->orWhere('description', 'like', $term)
                    ->orWhere('author', 'like', $term)
                    ->orWhere('tags', 'like', $term)
                    ->orWhereHas('subject', function ($subject) use ($term): void {
                        $subject->where('name', 'like', $term)
                            ->orWhere('short_name', 'like', $term);
                    });

                if (ctype_digit((string) $validated['q'])) {
                    $builder->orWhere('year', (int) $validated['q'])
                        ->orWhere('paper_number', (int) $validated['q']);
                }
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

    /**
     * The reflowable version of a document.
     *
     * Gated by the same entitlement as the file itself: a locked paper must not
     * leak its questions through the structured endpoint.
     */
    public function blocks(Request $request, Document $document): JsonResponse
    {
        if (! $document->is_published) {
            return $this->notFound('Document not found');
        }

        $user = $request->user();

        if ($user === null || ! app(EntitlementService::class)->canAccess($user, $document)) {
            return $this->forbidden('Subscribe or buy this paper to read it.');
        }

        $blocks = $document->blocks['blocks'] ?? null;

        if (! is_array($blocks) || $blocks === []) {
            return $this->notFound('This document has no structured version yet.');
        }

        return $this->success([
            'id' => $document->id,
            'title' => $document->title,
            'subtitle' => $document->blocks['subtitle'] ?? null,
            'format' => $document->format,
            'source_version' => $document->latest_version,
            'blocks' => $blocks,
        ]);
    }
}
