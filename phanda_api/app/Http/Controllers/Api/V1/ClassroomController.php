<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\ClassroomResource;
use App\Models\Classroom;
use App\Models\ClassroomAssignment;
use App\Models\Document;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * The service behind the Classes tab: a teacher creates a class and gets a code,
 * a learner joins with it, and the papers set for the class appear in the app.
 */
final class ClassroomController extends ApiController
{
    /** Classes this account runs as a teacher, or belongs to as a learner. */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $classes = Classroom::query()
            ->where('teacher_id', $user->getKey())
            ->orWhereHas('members', fn ($query) => $query->whereKey($user->getKey()))
            ->with(['teacher', 'assignments.document'])
            ->withCount('members')
            ->orderBy('name')
            ->get();

        return $this->success(ClassroomResource::collection($classes));
    }

    /** Staff create a class and read the code out to the room. */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'form' => ['required', 'integer', 'between:1,4'],
            'subject_id' => ['nullable', 'string', 'exists:subjects,id'],
        ]);

        $classroom = Classroom::query()->create([
            'name' => $validated['name'],
            'form' => $validated['form'],
            'subject_id' => $validated['subject_id'] ?? null,
            'teacher_id' => $request->user()->getKey(),
        ]);

        return $this->created(
            new ClassroomResource($classroom->load('teacher')->loadCount('members')),
            'Class created. Share the code with your learners.',
        );
    }

    public function show(Request $request, Classroom $classroom): JsonResponse
    {
        $this->ensureBelongs($request->user(), $classroom);

        return $this->success(new ClassroomResource(
            $classroom->load(['teacher', 'assignments.document'])->loadCount('members')
        ));
    }

    /** A learner joins with the code their teacher gave them. */
    public function join(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'code' => ['required', 'string', 'max:8'],
        ]);

        $code = strtoupper(trim($validated['code']));
        $classroom = Classroom::query()->where('code', $code)->first();

        if ($classroom === null) {
            // Deliberately vague about which part failed, but clear that the
            // code itself was not found: a learner can only retype it.
            return $this->error('No class uses that code. Check it with your teacher.', 404);
        }

        $user = $request->user();

        if (! $classroom->hasMember($user)) {
            $classroom->members()->attach($user->getKey(), ['joined_at' => now()]);
        }

        return $this->success(
            new ClassroomResource($classroom->load(['teacher', 'assignments.document'])->loadCount('members')),
            'Joined '.$classroom->name.'.',
        );
    }

    public function leave(Request $request, Classroom $classroom): JsonResponse
    {
        $classroom->members()->detach($request->user()->getKey());

        return $this->success(null, 'You have left '.$classroom->name.'.');
    }

    /** A teacher sets a paper for the class. */
    public function assign(Request $request, Classroom $classroom): JsonResponse
    {
        $this->ensureRuns($request->user(), $classroom);

        $validated = $request->validate([
            'document_id' => ['required', 'string', 'exists:documents,id'],
            'due_date' => ['nullable', 'date'],
        ]);

        $document = Document::query()->findOrFail($validated['document_id']);

        if (! $document->is_published) {
            return $this->error('That paper is not published, so learners cannot open it.', 422);
        }

        $assignment = ClassroomAssignment::query()->updateOrCreate(
            [
                'classroom_id' => $classroom->id,
                'document_id' => $document->id,
            ],
            [
                'due_date' => $validated['due_date'] ?? null,
                'set_by' => $request->user()->getKey(),
            ],
        );

        return $this->created(
            new ClassroomResource($classroom->load(['teacher', 'assignments.document'])->loadCount('members')),
            'Set '.$document->title.' for '.$classroom->name.'.',
        );
    }

    public function unassign(Request $request, Classroom $classroom, ClassroomAssignment $assignment): JsonResponse
    {
        $this->ensureRuns($request->user(), $classroom);
        abort_unless($assignment->classroom_id === $classroom->id, 404);

        $assignment->delete();

        return $this->success(
            new ClassroomResource($classroom->load(['teacher', 'assignments.document'])->loadCount('members')),
            'Assignment removed.',
        );
    }

    private function ensureBelongs(User $user, Classroom $classroom): void
    {
        abort_unless($classroom->isRunBy($user) || $classroom->hasMember($user), 403);
    }

    private function ensureRuns(User $user, Classroom $classroom): void
    {
        abort_unless($classroom->isRunBy($user), 403, 'Only the teacher who runs this class can change it.');
    }
}
