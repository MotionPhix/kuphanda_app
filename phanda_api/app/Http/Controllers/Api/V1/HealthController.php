<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Models\Document;
use Illuminate\Http\JsonResponse;

/**
 * A deployment's own report card.
 *
 * Twice now a fix has been committed, pushed and pulled, and the running site
 * behaved as though none of it had happened — either the pull landed in a
 * different checkout, PHP served cached bytecode, or a new class was not in the
 * composer classmap. Diagnosing that needed shell access and guesswork.
 *
 * One unauthenticated request now answers the questions that matter after a
 * deploy: is the catalogue the new one, is every published document readable,
 * and are the two integrations that fail silently actually configured. Nothing
 * here is a secret — a boolean and a transport name.
 */
final class HealthController
{
    public function __invoke(): JsonResponse
    {
        $published = Document::query()->where('is_published', true)->count();
        $readable = Document::query()->published()->readable()->count();

        return response()->json([
            'status' => 'ok',
            'time' => now()->toIso8601String(),
            'catalogue' => [
                'published' => $published,
                'readable' => $readable,
                'unreadable' => max(0, $published - $readable),
                'structured' => Document::query()
                    ->published()
                    ->whereNotNull('blocks')
                    ->count(),
                'last_content_update' => Document::query()->max('content_updated_at'),
            ],
            'features' => [
                // False means /auth/google answers 503 and the app says so.
                'google_sign_in' => filled(config('services.google.client_id')),
                // "log" means mail is discarded: sign-up works, no email arrives.
                'mail_transport' => config('mail.default'),
            ],
        ]);
    }
}
