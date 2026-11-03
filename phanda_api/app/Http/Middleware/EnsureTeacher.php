<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Running a class is a teacher's job, not only library staff's.
 *
 * Creating a class, setting a paper and reading the class report used to sit
 * behind the staff gate, which meant an account that answered "Teacher" during
 * onboarding — a teacher, but not a librarian — was refused. Library staff keep
 * the ability; so does anyone the service knows as a teacher.
 */
final class EnsureTeacher
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user === null || (! $user->is_staff && $user->role !== 'teacher')) {
            return response()->json([
                'success' => false,
                'message' => 'Only a teacher can run a class.',
                'data' => null,
            ], 403);
        }

        return $next($request);
    }
}
