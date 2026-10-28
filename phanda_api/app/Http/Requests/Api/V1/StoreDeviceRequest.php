<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

final class StoreDeviceRequest extends FormRequest
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
            'token' => ['required', 'string', 'min:20', 'max:255'],
            'platform' => ['required', 'string', Rule::in(['android', 'ios', 'web', 'other'])],
            'app_version' => ['nullable', 'string', 'max:32'],
        ];
    }
}
