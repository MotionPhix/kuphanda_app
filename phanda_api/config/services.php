<?php

declare(strict_types=1);

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'google' => [
        // Web/client ID used as the expected audience for Google ID tokens.
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],

    'firebase' => [
        // Same Firebase project as Google sign-in for the app.
        'project_id' => env('FIREBASE_PROJECT_ID'),
        // Absolute path to the service-account JSON. Keep it outside the
        // repository and outside the public directory.
        'credentials' => env('FIREBASE_CREDENTIALS'),
    ],

    'whatsapp' => [
        // Meta WhatsApp Cloud API, called directly: Kuphanda owns the WhatsApp
        // Business Account, so no provider sits in the middle taking a margin or
        // holding the message log. `phone_number_id` is the numeric ID in the app
        // dashboard, not the display number.
        'phone_number_id' => env('WHATSAPP_PHONE_NUMBER_ID'),
        // The WhatsApp Business Account id (WABA), not the phone number id.
        // Only used by `php artisan whatsapp:check` to read the template's
        // approval status; sending works without it.
        'business_account_id' => env('WHATSAPP_BUSINESS_ACCOUNT_ID'),
        // Permanent system-user token with whatsapp_business_messaging. Never the
        // 24-hour test token, which expires and takes sign-in with it.
        'token' => env('WHATSAPP_TOKEN'),
        // An AUTHENTICATION category template. Utility or marketing templates are
        // rejected for login codes.
        'template' => env('WHATSAPP_OTP_TEMPLATE', 'kuphanda_auth_code'),
        'language' => env('WHATSAPP_OTP_LANGUAGE', 'en_US'),
        'version' => env('WHATSAPP_API_VERSION', 'v21.0'),
        // True when the template carries a "Copy code" button, which needs the
        // code passed a second time against button index 0.
        'code_button' => (bool) env('WHATSAPP_OTP_CODE_BUTTON', true),
        // Echoed back by Meta's webhook handshake. Optional: delivery receipts
        // only, sign-in works without it.
        'webhook_verify_token' => env('WHATSAPP_WEBHOOK_VERIFY_TOKEN'),
    ],

    'paychangu' => [
        'base_url' => env('PAYCHANGU_BASE_URL', 'https://api.paychangu.com'),
        'secret_key' => env('PAYCHANGU_SECRET_KEY'),
        'webhook_secret' => env('PAYCHANGU_WEBHOOK_SECRET'),
        'currency' => env('PAYCHANGU_CURRENCY', 'MWK'),
    ],

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
