<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\ClassroomResource;
use App\Services\Push\PushDispatcher;
use Throwable;
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
    public function __construct(private readonly PushDispatcher $push) {}

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

        return $this->success(new ClassroomResource($this->loadFor($classroom, $request->user())));
    }

    /**
     * Loads a class the way the person looking at it needs to see it: with the
     * papers set, and — for a learner — which of them they have already finished.
     * Without this, "done" was a private note on one phone, so a learner who read
     * a paper on a tablet saw it unread on the school computer.
     */
    private function loadFor(Classroom $classroom, User $viewer): Classroom
    {
        return $classroom
            ->load([
                'teacher',
                'assignments.document',
                'assignments.completions' => fn ($query) => $query->where('user_id', $viewer->getKey()),
            ])
            ->loadCount('members');
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
            new ClassroomResource($this->loadFor($classroom, $request->user())),
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

        $this->tellTheClass($classroom, $assignment, $document, $request->user());

        return $this->created(
            new ClassroomResource($this->loadFor($classroom, $request->user())),
            'Set '.$document->title.' for '.$classroom->name.'.',
        );
    }

    /**
     * The class hears about reading the moment it is set.
     *
     * One message per learner, so it lands in their in-app inbox whether or not
     * the push token is alive — a phone that was off still shows it next time.
     * Best effort: a push provider problem must not undo the assignment.
     */
    /**
     * One message to the person who runs the class: a learner has finished the
     * paper they set. Best effort, like the announcement to the class.
     */
    private function tellTheTeacher(
        Classroom $classroom,
        ClassroomAssignment $assignment,
        User $learner,
    ): void {
        $teacher = $classroom->teacher;

        if ($teacher === null || $teacher->getKey() === $learner->getKey()) {
            return;
        }

        $document = $assignment->document;

        try {
            $this->push->toUser(
                $teacher,
                'completion',
                $learner->name.' finished '.($document?->title ?? 'a paper'),
                $classroom->name,
                [
                    'classroom_id' => (string) $classroom->id,
                    'assignment_id' => (string) $assignment->id,
                    'document_id' => (string) $assignment->document_id,
                ],
            );
        } catch (Throwable $error) {
            report($error);
        }
    }

    private function tellTheClass(
        Classroom $classroom,
        ClassroomAssignment $assignment,
        Document $document,
        User $teacher,
    ): void {
        $members = $classroom->members()
            ->where('users.id', '!=', $teacher->getKey())
            ->get();

        foreach ($members as $member) {
            try {
                $this->push->toUser(
                    $member,
                    'assignment',
                    'New reading: '.$document->title,
                    $teacher->name.' set this for '.$classroom->name,
                    [
                        'classroom_id' => (string) $classroom->id,
                        'assignment_id' => (string) $assignment->id,
                        'document_id' => (string) $document->id,
                    ],
                );
            } catch (Throwable $error) {
                report($error);
            }
        }
    }

    public function unassign(Request $request, Classroom $classroom, ClassroomAssignment $assignment): JsonResponse
    {
        $this->ensureRuns($request->user(), $classroom);
        abort_unless($assignment->classroom_id === $classroom->id, 404);

        $assignment->delete();

        return $this->success(
            new ClassroomResource($this->loadFor($classroom, $request->user())),
            'Assignment removed.',
        );
    }

    /**
     * A learner says they have finished a paper the class was set.
     *
     * Idempotent: reading it twice is not two completions. Only a member of the
     * class may write this, so a code alone cannot mark someone else's work.
     */
    public function complete(Request $request, ClassroomAssignment $assignment): JsonResponse
    {
        $classroom = $assignment->classroom;
        abort_if($classroom === null, 404);

        abort_unless(
            $classroom->hasMember($request->user()),
            403,
            'Join the class before marking its reading done.',
        );

        $completion = $assignment->completions()->firstOrCreate(
            ['user_id' => $request->user()->getKey()],
            ['completed_at' => now()],
        );

        // The teacher hears about a finish once, when it happens — not every time
        // the same paper is reopened. Someone who runs the class and also reads
        // it does not get told about themselves.
        if ($completion->wasRecentlyCreated) {
            $this->tellTheTeacher($classroom, $assignment, $request->user());
        }

        return $this->success([
            'assignment_id' => $assignment->id,
            'classroom_id' => $classroom->id,
            'completed_at' => $completion->completed_at?->toIso8601String(),
        ], 'Marked as read.');
    }

    /**
     * The teacher's report: who is in the class, what was set, and who has read
     * it. A learner gets 403 — this is the one class view that is not shared.
     */
    public function report(Request $request, Classroom $classroom): JsonResponse
    {
        $this->ensureRuns($request->user(), $classroom);

        $assignments = $classroom->assignments()
            ->with(['document', 'completions'])
            ->orderBy('created_at')
            ->get();

        $members = $classroom->members()
            ->orderBy('name')
            ->get(['users.id', 'users.name']);

        return $this->success([
            'classroom' => new ClassroomResource(
                $classroom->load('teacher')->loadCount('members')
            ),
            'assignments' => $assignments->map(fn (ClassroomAssignment $assignment): array => [
                'id' => $assignment->id,
                'document_id' => $assignment->document_id,
                'title' => $assignment->document?->title,
                'due_date' => $assignment->due_date?->toDateString(),
                'completed_count' => $assignment->completions->count(),
            ])->all(),
            'learners' => $members->map(function (User $member) use ($assignments): array {
                $done = $assignments
                    ->filter(fn (ClassroomAssignment $assignment): bool => $assignment->completions
                        ->contains('user_id', $member->getKey()))
                    ->pluck('id')
                    ->values()
                    ->all();

                return [
                    'id' => $member->getKey(),
                    'name' => $member->name,
                    'completed_assignment_ids' => $done,
                    'completed_count' => count($done),
                ];
            })->all(),
            'assignment_count' => $assignments->count(),
            'learner_count' => $members->count(),
        ]);
    }

    private function ensureBelongs(User $user, Classroom $classroom): void
    {
        abort_unless($classroom->isRunBy($user) || $classroom->hasMember($user), 403);
    }

    /**
     * Nudges the learners who have not read a paper yet.
     *
     * One message each to the people still to do it, never the whole class, so a
     * reminder does not become noise for those who already read it. Returns how
     * many were sent so the app can say so.
     */
    public function remind(Request $request, Classroom $classroom, ClassroomAssignment $assignment): JsonResponse
    {
        $this->ensureRuns($request->user(), $classroom);
        abort_unless($assignment->classroom_id === $classroom->id, 404);

        $done = $assignment->completions()->pluck('user_id')->all();
        $members = $classroom->members()
            ->whereNotIn('users.id', $done)
            ->get();

        $title = $assignment->document?->title ?? 'a paper';
        $sent = 0;

        foreach ($members as $member) {
            try {
                $this->push->toUser(
                    $member,
                    'reminder',
                    'Still to read: '.$title,
                    $classroom->name.' · set by '.$request->user()->name,
                    [
                        'classroom_id' => (string) $classroom->id,
                        'assignment_id' => (string) $assignment->id,
                        'document_id' => (string) $assignment->document_id,
                    ],
                );
                $sent++;
            } catch (Throwable $error) {
                report($error);
            }
        }

        return $this->success(
            ['sent' => $sent, 'assignment_id' => (string) $assignment->id],
            $sent === 1 ? 'Reminded one learner.' : 'Reminded '.$sent.' learners.',
        );
    }
    private function ensureRuns(User $user, Classroom $classroom): void
    {
        abort_unless($classroom->isRunBy($user), 403, 'Only the teacher who runs this class can change it.');
    }
}




