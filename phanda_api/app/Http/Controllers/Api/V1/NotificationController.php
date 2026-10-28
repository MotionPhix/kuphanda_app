<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\DispatchNotificationRequest;
use App\Models\PushMessage;
use App\Models\User;
use App\Services\Push\PushDispatcher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class NotificationController extends ApiController
{
    public function __construct(private readonly PushDispatcher $push) {}

    /**
     * The learner's recent messages, including the ones delivered by push so
     * the app can show an in-app inbox when a notification is missed.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $messages = PushMessage::query()
            ->where(function ($query) use ($user): void {
                $query->where('audience', PushDispatcher::AUDIENCE_ALL);

                $roleAudience = $user->role === 'teacher'
                    ? PushDispatcher::AUDIENCE_TEACHERS
                    : PushDispatcher::AUDIENCE_STUDENTS;

                $query->orWhere('audience', $roleAudience);

                if ($user->form !== null) {
                    $query->orWhere(function ($formQuery) use ($user): void {
                        $formQuery
                            ->where('audience', PushDispatcher::AUDIENCE_FORM)
                            ->where('audience_value', (string) $user->form);
                    });
                }

                $query->orWhere(function ($ownQuery) use ($user): void {
                    $ownQuery
                        ->where('audience', PushDispatcher::AUDIENCE_USER)
                        ->where('audience_value', (string) $user->id);
                });
            })
            ->orderByDesc('created_at')
            ->limit(50)
            ->get()
            ->map(fn (PushMessage $message): array => [
                'id' => $message->id,
                'category' => $message->category,
                'title' => $message->title,
                'body' => $message->body,
                'data' => $message->data ?? [],
                'sent_at' => $message->created_at?->toIso8601String(),
            ]);

        return $this->success($messages);
    }

    /**
     * Sends a message to an audience segment. Restricted to staff so a learner
     * account can never broadcast.
     */
    public function store(DispatchNotificationRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if (! $user->is_staff && $user->role !== 'teacher') {
            return $this->forbidden('Only staff and teachers can send notifications.');
        }

        $audience = (string) $request->validated('audience');
        $form = $request->validated('form');

        // A teacher may message learners, never the whole school or other
        // teachers. Library staff keep the full audience.
        if (! $user->is_staff
            && in_array($audience, [PushDispatcher::AUDIENCE_ALL, PushDispatcher::AUDIENCE_TEACHERS], true)
        ) {
            return $this->forbidden('Teachers can send notifications to students only.');
        }

        $data = array_filter([
            'document_id' => $request->validated('document_id'),
            'route' => $request->validated('route'),
        ], fn ($value): bool => $value !== null);

        $message = $this->push->broadcast(
            audience: $audience,
            audienceValue: $audience === PushDispatcher::AUDIENCE_FORM ? (string) $form : null,
            category: (string) ($request->validated('category') ?? 'general'),
            title: (string) $request->validated('title'),
            body: (string) $request->validated('body'),
            data: $data,
            sender: $user,
        );

        return $this->created([
            'id' => $message->id,
            'audience' => $message->audience,
            'audience_value' => $message->audience_value,
            'delivered' => $message->delivered,
            'failed' => $message->failed,
        ], 'Notification queued');
    }

    /**
     * Staff view of what has been sent.
     */
    public function sent(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        if (! $user->is_staff) {
            return $this->forbidden('Only staff can review notifications.');
        }

        $messages = PushMessage::query()
            ->where('audience', '!=', PushDispatcher::AUDIENCE_USER)
            ->orderByDesc('created_at')
            ->limit(100)
            ->get()
            ->map(fn (PushMessage $message): array => [
                'id' => $message->id,
                'audience' => $message->audience,
                'audience_value' => $message->audience_value,
                'category' => $message->category,
                'title' => $message->title,
                'body' => $message->body,
                'delivered' => $message->delivered,
                'failed' => $message->failed,
                'sent_at' => $message->created_at?->toIso8601String(),
            ]);

        return $this->success($messages);
    }
}
