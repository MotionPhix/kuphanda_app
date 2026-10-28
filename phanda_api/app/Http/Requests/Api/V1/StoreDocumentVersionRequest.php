<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

final class StoreDocumentVersionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->is_staff === true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'file' => ['required', 'file', 'mimes:pdf', 'max:51200'],
            'pages' => ['required', 'integer', 'min:1', 'max:5000'],
            'notes' => ['nullable', 'string', 'max:500'],
        ];
    }
}
