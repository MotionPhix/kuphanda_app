<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Publishing is restricted to library staff accounts provisioned by an
 * administrator; learners and teachers cannot upload catalogue files.
 */
final class EnsureStaff
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user === null || ! $user->is_staff) {
            return response()->json([
                'success' => false,
                'message' => 'Staff access is required for this action.',
                'data' => null,
            ], 403);
        }

        return $next($request);
    }
}
