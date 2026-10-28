<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

final class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'first_name' => ['sometimes', 'string', 'max:80'],
            'last_name' => ['sometimes', 'string', 'max:80'],
            'name' => ['sometimes', 'string', 'max:160'],
            'school' => ['sometimes', 'nullable', 'string', 'max:120'],
            'role' => ['sometimes', 'string', Rule::in(['student', 'teacher'])],
            'form' => ['sometimes', 'nullable', 'integer', 'between:1,4'],
        ];
    }
}
