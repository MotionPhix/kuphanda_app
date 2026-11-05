<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Asks for a sign-in code.
 *
 * `purpose` is part of the contract because the three cases are genuinely
 * different: signing in must not create an account, signing up must not sign in
 * to an existing one, and linking must happen from inside a session.
 *
 * @property string $phone
 * @property string $purpose
 */
final class StartOtpRequest extends FormRequest
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
            // Deliberately not `phone:` rules: Malawian numbers arrive as
            // 0991 234 567 far more often than as E.164, and localised parsing
            // here would be stricter than the people using it.
            'phone' => ['required', 'string', 'max:32'],
            'purpose' => ['required', 'string', 'in:login,signup,link'],
        ];
    }
}
