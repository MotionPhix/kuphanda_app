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
