<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Models\Document;
use App\Contracts\PushSender;
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
    public function __invoke(PushSender $push): JsonResponse
    {
        $published = Document::query()->where('is_published', true)->count();
        $readable = Document::query()->published()->readable()->count();

        return response()->json([
            'status' => 'ok',
            'time' => now()->toIso8601String(),
            // The commit the running code was checked out at, written by
            // deploy/update.sh. Without it "did the pull land?" is guesswork:
            // the file says what is on disk, this says what was recorded at
            // deploy time, and a disagreement is the answer.
            'commit' => $this->commit(),
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
                // Class notifications are pushed through FCM. With no service
                // account this is false and notifications only ever reach a
                // phone that happens to be open — worth knowing before blaming
                // the app for silence.
                'push' => ['configured' => $push->isConfigured()],
            ],
        ]);
    }

    /**
     * @return string|null  null on a checkout that has never been deployed by
     *                      update.sh, which is itself useful information.
     */
    private function commit(): ?string
    {
        $path = storage_path('app/current-commit');

        if (! is_file($path)) {
            return null;
        }

        $commit = trim((string) @file_get_contents($path));

        return $commit === '' ? null : mb_substr($commit, 0, 40);
    }
}


