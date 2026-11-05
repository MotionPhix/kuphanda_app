<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
final class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'first_name' => $this->first_name,
            'last_name' => $this->last_name,
            'avatar_url' => $this->avatar_url,
            'google_linked' => $this->google_id !== null,
            'is_staff' => (bool) $this->is_staff,
            'school' => $this->school,
            'email' => $this->email,
            // The stored number and whether a code proved it. The app shows the
            // number back on the profile screen and decides whether "sign in
            // with WhatsApp" is a thing this account can do.
            'phone' => $this->phone_e164,
            'phone_verified' => $this->phone_verified_at !== null,
            'plan' => $this->plan->value,
            'role' => $this->role,
            'form' => $this->form,
            'profile_completed' => $this->profile_completed_at !== null,
            'email_verified_at' => $this->email_verified_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
