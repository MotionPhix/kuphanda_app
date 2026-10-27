<?php

declare(strict_types=1);

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

final class CheckoutRequest extends FormRequest
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
            'plan_id' => ['nullable', 'integer', 'exists:plans,id'],
            'document_id' => ['nullable', 'string', 'exists:documents,id'],
        ];
    }

    /**
     * Exactly one of plan_id or document_id.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $hasPlan = $this->filled('plan_id');
            $hasDocument = $this->filled('document_id');

            if ($hasPlan === $hasDocument) {
                $validator->errors()->add(
                    'plan_id',
                    'Choose either a subscription plan or a single document.'
                );
            }
        });
    }
}
