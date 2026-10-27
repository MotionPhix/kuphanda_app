<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class ForceJsonResponse
{
    /**
     * Ensure all responses are JSON and set proper Accept header.
     */
    public function handle(Request $request, Closure $next): mixed
    {
        $request->headers->set('Accept', 'application/json');

        $response = $next($request);

        if ($response instanceof JsonResponse) {
            return $response;
        }

        // File downloads, empty responses and 304s must keep their headers and
        // body; wrapping them in JSON would corrupt the download.
        if ($response instanceof StreamedResponse || $response instanceof BinaryFileResponse) {
            return $response;
        }

        if (in_array($response->getStatusCode(), [204, 304], true)) {
            return $response;
        }

        // Convert other non-JSON responses to JSON
        if ($response instanceof Response) {
            return response()->json([
                'success' => false,
                'message' => 'An error occurred',
                'data' => $response->getContent(),
            ], $response->getStatusCode());
        }

        return $response;
    }
}
