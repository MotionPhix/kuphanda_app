<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

final class DispatchNotificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'audience' => ['required', Rule::in(['all', 'students', 'teachers', 'form'])],
            'form' => ['required_if:audience,form', 'nullable', 'integer', 'between:1,4'],
            'category' => ['nullable', Rule::in(['general', 'class', 'reminder', 'document'])],
            'title' => ['required', 'string', 'max:160'],
            'body' => ['required', 'string', 'max:500'],
            'document_id' => ['nullable', 'string', 'max:64'],
            'route' => ['nullable', 'string', 'max:64'],
        ];
    }
}
