<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BillingController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\DownloadController;
use App\Http\Controllers\Api\V1\OfflineLibraryController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API V1 Routes
|--------------------------------------------------------------------------
|
| Routes for API version 1.
|
*/

// Public routes with auth rate limiter (5/min - brute force protection)
Route::middleware('throttle:auth')->group(function (): void {
    Route::post('register', [AuthController::class, 'register'])->name('api.v1.register');
    Route::post('login', [AuthController::class, 'login'])->name('api.v1.login');
    Route::post('auth/google', [AuthController::class, 'google'])->name('api.v1.auth.google');
});

// Protected routes with authenticated rate limiter (120/min)
Route::middleware(['auth:sanctum', 'throttle:authenticated'])->group(function (): void {
    Route::post('logout', [AuthController::class, 'logout'])->name('api.v1.logout');
    Route::get('me', [AuthController::class, 'me'])->name('api.v1.me');

    // Catalogue
    Route::get('subjects', [CatalogController::class, 'subjects'])->name('api.v1.subjects.index');
    Route::get('documents', [CatalogController::class, 'documents'])->name('api.v1.documents.index');
    Route::get('documents/{document}', [CatalogController::class, 'show'])->name('api.v1.documents.show');

    // Offline library: explicit marks, download, acknowledgement, sync, removal.
    Route::get('library/offline', [OfflineLibraryController::class, 'index'])
        ->name('api.v1.library.offline.index');
    Route::post('library/offline', [OfflineLibraryController::class, 'store'])
        ->name('api.v1.library.offline.store');
    Route::delete('library/offline/{document}', [OfflineLibraryController::class, 'destroy'])
        ->name('api.v1.library.offline.destroy');
    Route::get('library/offline/{document}/download', DownloadController::class)
        ->name('api.v1.library.download');
    Route::post('library/offline/{document}/ack', [OfflineLibraryController::class, 'ack'])
        ->name('api.v1.library.ack');
    Route::get('library/sync', [OfflineLibraryController::class, 'sync'])
        ->name('api.v1.library.sync');

    // Subscriptions, single-document purchases and PayChangu checkout
    Route::get('plans', [BillingController::class, 'plans'])->name('api.v1.plans.index');
    Route::get('billing/status', [BillingController::class, 'status'])->name('api.v1.billing.status');
    Route::post('billing/checkout', [BillingController::class, 'checkout'])->name('api.v1.billing.checkout');
    Route::get('billing/payments', [BillingController::class, 'payments'])->name('api.v1.billing.payments');
    Route::get('billing/payments/{txRef}', [BillingController::class, 'payment'])->name('api.v1.billing.payment');

    // Email verification
    Route::post('email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])
        ->middleware('signed')
        ->name('verification.verify');
    Route::post('email/resend', [AuthController::class, 'resendVerificationEmail'])
        ->middleware('throttle:6,1')
        ->name('verification.send');
});

// PayChangu redirect and webhook (no auth: the provider calls these)
Route::get('billing/callback/{txRef}', [BillingController::class, 'callback'])
    ->name('api.v1.billing.callback');
Route::post('webhooks/paychangu', [BillingController::class, 'webhook'])
    ->middleware('throttle:60,1')
    ->name('api.v1.webhooks.paychangu');

// Password reset routes (public with rate limiting)
Route::middleware('throttle:6,1')->group(function (): void {
    Route::post('forgot-password', [AuthController::class, 'forgotPassword'])
        ->name('password.email');
    Route::post('reset-password', [AuthController::class, 'resetPassword'])
        ->name('password.reset');
});
