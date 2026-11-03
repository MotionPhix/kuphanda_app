<?php

declare(strict_types=1);

use App\Models\Classroom;
use App\Models\Document;
use App\Models\Subject;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function reportDocument(string $id = 'ref-msce-physics-2003-p1'): Document
{
    Subject::query()->firstOrCreate(
        ['id' => 'physics'],
        ['name' => 'Physics', 'short_name' => 'Physics', 'forms' => [3, 4], 'sort_order' => 5],
    );

    return Document::query()->create([
        'id' => $id,
        'subject_id' => 'physics',
        'title' => 'Physics Paper I',
        'form' => 4,
        'kind' => 'pastPaper',
        'description' => 'A test paper.',
        'pages' => 8,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ]);
}

function reportClassroom(User $teacher): Classroom
{
    return Classroom::query()->create([
        'name' => 'Form 4 Physics',
        'form' => 4,
        'subject_id' => 'physics',
        'teacher_id' => $teacher->getKey(),
    ]);
}

it('shows a teacher who has read the paper they set', function (): void {
    $teacher = User::factory()->create(['is_staff' => true]);
    $learner = User::factory()->create(['name' => 'Tadala Phiri']);
    $classroom = reportClassroom($teacher);
    $classroom->members()->attach($learner->getKey(), ['joined_at' => now()]);

    $document = reportDocument();
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ])->assertStatus(201);

    $assignmentId = $classroom->assignments()->firstOrFail()->id;

    // The learner finishes it.
    $this->actingAs($learner)
        ->postJson("/api/v1/assignments/{$assignmentId}/complete")
        ->assertOk()
        ->assertJsonPath('data.assignment_id', $assignmentId);

    $this->actingAs($teacher)
        ->getJson("/api/v1/classrooms/{$classroom->id}/report")
        ->assertOk()
        ->assertJsonPath('data.learner_count', 1)
        ->assertJsonPath('data.assignment_count', 1)
        ->assertJsonPath('data.assignments.0.completed_count', 1)
        ->assertJsonPath('data.learners.0.name', 'Tadala Phiri')
        ->assertJsonPath('data.learners.0.completed_count', 1)
        ->assertJsonPath('data.learners.0.completed_assignment_ids.0', $assignmentId);
});

it('counts one completion when the same paper is read twice', function (): void {
    $teacher = User::factory()->create(['is_staff' => true]);
    $learner = User::factory()->create();
    $classroom = reportClassroom($teacher);
    $classroom->members()->attach($learner->getKey(), ['joined_at' => now()]);

    $document = reportDocument('ref-msce-physics-2004-p1');
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ]);
    $assignmentId = $classroom->assignments()->firstOrFail()->id;

    foreach ([1, 2] as $attempt) {
        $this->actingAs($learner)
            ->postJson("/api/v1/assignments/{$assignmentId}/complete")
            ->assertOk();
    }

    $this->actingAs($teacher)
        ->getJson("/api/v1/classrooms/{$classroom->id}/report")
        ->assertOk()
        ->assertJsonPath('data.assignments.0.completed_count', 1)
        ->assertJsonPath('data.learners.0.completed_count', 1);
});

it('keeps the report to the teacher who runs the class', function (): void {
    $teacher = User::factory()->create(['is_staff' => true]);
    $learner = User::factory()->create();
    $classroom = reportClassroom($teacher);
    $classroom->members()->attach($learner->getKey(), ['joined_at' => now()]);

    $this->actingAs($learner)
        ->getJson("/api/v1/classrooms/{$classroom->id}/report")
        ->assertForbidden();
});

it('will not let someone outside the class mark its reading done', function (): void {
    $teacher = User::factory()->create(['is_staff' => true]);
    $classroom = reportClassroom($teacher);

    $document = reportDocument('ref-msce-physics-2005-p1');
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ]);
    $assignmentId = $classroom->assignments()->firstOrFail()->id;

    $this->actingAs(User::factory()->create())
        ->postJson("/api/v1/assignments/{$assignmentId}/complete")
        ->assertForbidden();
});

it('tells each learner which papers they have already read, on any device', function (): void {
    $teacher = User::factory()->create(['is_staff' => true]);
    $tadala = User::factory()->create(['name' => 'Tadala Phiri']);
    $chisomo = User::factory()->create(['name' => 'Chisomo Banda']);

    $classroom = reportClassroom($teacher);
    $classroom->members()->attach([$tadala->getKey(), $chisomo->getKey()], ['joined_at' => now()]);

    $document = reportDocument('ref-msce-physics-2006-p1');
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ]);
    $assignmentId = $classroom->assignments()->firstOrFail()->id;

    $this->actingAs($tadala)
        ->postJson("/api/v1/assignments/{$assignmentId}/complete")
        ->assertOk();

    // Tadala reads it; the class shows it done for her and not for Chisomo.
    $this->actingAs($tadala)
        ->getJson("/api/v1/classrooms/{$classroom->id}")
        ->assertOk()
        ->assertJsonPath('data.assignments.0.completed', true);

    $this->actingAs($chisomo)
        ->getJson("/api/v1/classrooms/{$classroom->id}")
        ->assertOk()
        ->assertJsonPath('data.assignments.0.completed', false);
});

it('tells the learners when a paper is set, and not the teacher', function (): void {
    $teacher = User::factory()->create(['is_staff' => true, 'name' => 'Grace Mwale']);
    $tadala = User::factory()->create(['name' => 'Tadala Phiri']);
    $chisomo = User::factory()->create(['name' => 'Chisomo Banda']);

    $classroom = reportClassroom($teacher);
    $classroom->members()->attach([$tadala->getKey(), $chisomo->getKey()], ['joined_at' => now()]);

    $document = reportDocument('ref-msce-physics-2007-p1');
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ])->assertStatus(201);

    $assignmentId = (string) $classroom->assignments()->firstOrFail()->id;

    $this->actingAs($tadala)
        ->getJson('/api/v1/me/notifications')
        ->assertOk()
        ->assertJsonPath('data.0.category', 'assignment')
        ->assertJsonPath('data.0.title', 'New reading: Physics Paper I')
        ->assertJsonPath('data.0.data.classroom_id', (string) $classroom->id)
        ->assertJsonPath('data.0.data.assignment_id', $assignmentId)
        ->assertJsonPath('data.0.data.document_id', $document->id);

    $this->actingAs($chisomo)
        ->getJson('/api/v1/me/notifications')
        ->assertOk()
        ->assertJsonPath('data.0.category', 'assignment');

    // The person who set it does not get told about their own action.
    $this->actingAs($teacher)
        ->getJson('/api/v1/me/notifications')
        ->assertOk()
        ->assertJsonCount(0, 'data');
});

it('tells the teacher when a learner finishes, once', function (): void {
    $teacher = User::factory()->create(['is_staff' => true, 'name' => 'Grace Mwale']);
    $learner = User::factory()->create(['name' => 'Tadala Phiri']);

    $classroom = reportClassroom($teacher);
    $classroom->members()->attach($learner->getKey(), ['joined_at' => now()]);

    $document = reportDocument('ref-msce-physics-2008-p1');
    $this->actingAs($teacher)->postJson("/api/v1/classrooms/{$classroom->id}/assignments", [
        'document_id' => $document->id,
    ]);
    $assignmentId = (string) $classroom->assignments()->firstOrFail()->id;

    // Reading it twice is one finish, and one message.
    foreach ([1, 2] as $attempt) {
        $this->actingAs($learner)
            ->postJson("/api/v1/assignments/{$assignmentId}/complete")
            ->assertOk();
    }

    $this->actingAs($teacher)
        ->getJson('/api/v1/me/notifications')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.category', 'completion')
        ->assertJsonPath('data.0.title', 'Tadala Phiri finished Physics Paper I')
        ->assertJsonPath('data.0.data.assignment_id', $assignmentId)
        ->assertJsonPath('data.0.data.classroom_id', (string) $classroom->id);
});
