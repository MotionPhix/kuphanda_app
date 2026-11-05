<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Hands back the code that was sent.
 *
 * `name` is only read for a sign-up: the account is created at this moment, and
 * a library card with no name on it is not usable by a teacher setting work.
 *
 * @property string $challenge
 * @property string $code
 * @property string|null $name
 */
final class VerifyOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'challenge' => ['required', 'string', 'max:40'],
            // Six digits, but a paste from WhatsApp can carry a space, so the
            // service strips non-digits rather than rejecting the attempt.
            'code' => ['required', 'string', 'max:12'],
            'name' => ['nullable', 'string', 'max:255'],
        ];
    }
}
