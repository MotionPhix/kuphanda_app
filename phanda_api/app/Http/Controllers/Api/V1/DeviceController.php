<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Api\ApiController;
use App\Http\Requests\Api\V1\RemoveDeviceRequest;
use App\Http\Requests\Api\V1\StoreDeviceRequest;
use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class DeviceController extends ApiController
{
    /**
     * Registers or refreshes this installation's FCM token.
     *
     * The token is unique across the table, so signing in on a shared phone
     * moves delivery to the new account instead of leaving the old one able to
     * receive notifications on that device.
     */
    public function store(StoreDeviceRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $device = DeviceToken::query()->updateOrCreate(
            ['token' => (string) $request->validated('token')],
            [
                'user_id' => $user->id,
                'platform' => (string) $request->validated('platform'),
                'app_version' => $request->validated('app_version'),
                'last_seen_at' => now(),
            ],
        );

        return $this->success([
            'id' => $device->id,
            'platform' => $device->platform,
            'last_seen_at' => $device->last_seen_at?->toIso8601String(),
        ], 'Device registered');
    }

    /**
     * Removes this installation. Scoped to the caller: a learner can never
     * unregister somebody else's device.
     */
    public function destroy(RemoveDeviceRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        DeviceToken::query()
            ->where('user_id', $user->id)
            ->where('token', (string) $request->validated('token'))
            ->delete();

        return $this->success(null, 'Device removed');
    }

    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $devices = DeviceToken::query()
            ->where('user_id', $user->id)
            ->orderByDesc('last_seen_at')
            ->get()
            ->map(fn (DeviceToken $device): array => [
                'id' => $device->id,
                'platform' => $device->platform,
                'app_version' => $device->app_version,
                'last_seen_at' => $device->last_seen_at?->toIso8601String(),
            ]);

        return $this->success($devices);
    }
}
