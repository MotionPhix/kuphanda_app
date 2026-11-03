<?php

declare(strict_types=1);

use App\Models\Classroom;
use App\Models\Document;
use App\Models\Subject;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function classroomDocument(string $id = 'ref-msce-maths-2002-p1'): Document
{
    Subject::query()->firstOrCreate(
        ['id' => 'mathematics'],
        ['name' => 'Mathematics', 'short_name' => 'Maths', 'forms' => [1, 2, 3, 4], 'sort_order' => 1],
    );

    return Document::query()->create([
        'id' => $id,
        'subject_id' => 'mathematics',
        'title' => 'Mathematics Paper I',
        'form' => 4,
        'kind' => 'pastPaper',
        'description' => 'A test paper.',
        'pages' => 6,
        'access_tier' => 'free',
        'is_published' => true,
        'latest_version' => 0,
    ]);
}

function classroomTeacher(): User
{
    return User::factory()->create(['is_staff' => true]);
}

it('gives a new class a code that can be read out loud', function (): void {
    $teacher = classroomTeacher();

    $response = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ]);

    $response->assertStatus(201)
        ->assertJsonPath('data.name', 'Form 4A — Sciences')
        ->assertJsonPath('data.member_count', 0)
        ->assertJsonPath('data.is_owner', true);

    $code = $response->json('data.code');

    // Six characters, and none of the ones that get misread on a blackboard.
    expect($code)->toHaveLength(6)
        ->and($code)->toMatch('/^[ABCDEFGHJKLMNPQRTUVWXYZ2346789]{6}$/');
});

it('refuses to create a class for a learner', function (): void {
    $student = User::factory()->create(['is_staff' => false]);

    $this->actingAs($student)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A',
        'form' => 4,
    ])->assertStatus(403);
});

it('lets a learner join with the code and see the class', function (): void {
    $teacher = classroomTeacher();
    $student = User::factory()->create();

    $code = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ])->json('data.code');

    $this->actingAs($student)->postJson('/api/v1/classrooms/join', ['code' => strtolower($code)])
        ->assertStatus(200)
        ->assertJsonPath('data.code', $code)
        ->assertJsonPath('data.member_count', 1)
        ->assertJsonPath('data.is_owner', false)
        ->assertJsonPath('data.teacher_name', $teacher->name);

    $this->actingAs($student)->getJson('/api/v1/classrooms')
        ->assertStatus(200)
        ->assertJsonCount(1, 'data');
});

it('says clearly when no class uses the code', function (): void {
    $student = User::factory()->create();

    $this->actingAs($student)->postJson('/api/v1/classrooms/join', ['code' => 'ZZZZZZ'])
        ->assertStatus(404)
        ->assertJsonPath('success', false)
        ->assertJsonPath('message', 'No class uses that code. Check it with your teacher.');
});

it('keeps a class private to its teacher and members', function (): void {
    $teacher = classroomTeacher();
    $outsider = User::factory()->create();

    $id = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 2B — Mathematics',
        'form' => 2,
    ])->json('data.id');

    $this->actingAs($outsider)->getJson('/api/v1/classrooms/'.$id)->assertStatus(403);
});

it('shows a learner the paper their teacher set, once', function (): void {
    $teacher = classroomTeacher();
    $student = User::factory()->create();
    $document = classroomDocument();

    $id = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ])->json('data.id');

    $this->actingAs($student)->postJson('/api/v1/classrooms/join', [
        'code' => Classroom::query()->find($id)->code,
    ])->assertStatus(200);

    $this->actingAs($teacher)->postJson('/api/v1/classrooms/'.$id.'/assignments', [
        'document_id' => $document->id,
        'due_date' => '2026-11-02',
    ])->assertStatus(201)
        ->assertJsonPath('data.assignments.0.document_id', $document->id)
        ->assertJsonPath('data.assignments.0.title', 'Mathematics Paper I')
        ->assertJsonPath('data.assignments.0.due_date', '2026-11-02');

    // Setting it again updates the due date rather than duplicating the row.
    $this->actingAs($teacher)->postJson('/api/v1/classrooms/'.$id.'/assignments', [
        'document_id' => $document->id,
        'due_date' => '2026-11-09',
    ])->assertStatus(201);

    $this->actingAs($student)->getJson('/api/v1/classrooms')
        ->assertStatus(200)
        ->assertJsonCount(1, 'data.0.assignments')
        ->assertJsonPath('data.0.assignments.0.due_date', '2026-11-09');
});

it('only lets the teacher who runs a class change what is set', function (): void {
    $teacher = classroomTeacher();
    $other = classroomTeacher();
    $document = classroomDocument();

    $id = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ])->json('data.id');

    $this->actingAs($other)->postJson('/api/v1/classrooms/'.$id.'/assignments', [
        'document_id' => $document->id,
    ])->assertStatus(403);
});

it('will not set a paper that is not published', function (): void {
    $teacher = classroomTeacher();
    $document = classroomDocument('draft-paper');
    $document->forceFill(['is_published' => false])->save();

    $id = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ])->json('data.id');

    $this->actingAs($teacher)->postJson('/api/v1/classrooms/'.$id.'/assignments', [
        'document_id' => $document->id,
    ])->assertStatus(422);
});

it('lets a learner leave a class', function (): void {
    $teacher = classroomTeacher();
    $student = User::factory()->create();

    $classroom = $this->actingAs($teacher)->postJson('/api/v1/classrooms', [
        'name' => 'Form 4A — Sciences',
        'form' => 4,
    ])->json();

    $this->actingAs($student)->postJson('/api/v1/classrooms/join', ['code' => $classroom['data']['code']]);

    $this->actingAs($student)
        ->deleteJson('/api/v1/classrooms/'.$classroom['data']['id'].'/leave')
        ->assertStatus(200);

    $this->actingAs($student)->getJson('/api/v1/classrooms')->assertJsonCount(0, 'data');
});

it('lets a teacher who is not library staff run a class', function (): void {
    // Onboarding asks "Student or Teacher"; that answer is a role, not a staff
    // badge. The class tools used to sit behind the staff gate and refused them.
    $teacher = User::factory()->create(['role' => 'teacher', 'is_staff' => false]);

    $this->actingAs($teacher)
        ->postJson('/api/v1/classrooms', ['name' => 'Form 3 Science', 'form' => 3])
        ->assertStatus(201)
        ->assertJsonPath('data.is_owner', true);
});

it('still refuses a learner the class tools', function (): void {
    $learner = User::factory()->create(['role' => 'student', 'is_staff' => false]);

    $this->actingAs($learner)
        ->postJson('/api/v1/classrooms', ['name' => 'Not mine', 'form' => 2])
        ->assertForbidden();
});
