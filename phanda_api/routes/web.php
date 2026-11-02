<?php

declare(strict_types=1);

use App\Http\Controllers\PasswordResetPageController;
use Illuminate\Support\Facades\Route;

// API only, with one exception: the link in the password-reset email has to
// open something a phone browser can render. Everything else lives under
// /api/v1.
// Scramble documentation available at /docs/api

Route::get('/reset-password', [PasswordResetPageController::class, 'show'])
    ->name('password.reset.page');

Route::get('/reset-password/done', [PasswordResetPageController::class, 'done'])
    ->name('password.reset.done');

Route::post('/reset-password', [PasswordResetPageController::class, 'update'])
    ->name('password.reset.submit');
