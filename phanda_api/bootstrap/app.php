<?php

declare(strict_types=1);

use App\Http\Middleware\EnsureEmailVerified;
use App\Http\Middleware\EnsureStaff;
use App\Http\Middleware\ForceJsonResponse;
use App\Http\Middleware\LogApiRequests;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Behind a tunnel (ngrok, a load balancer) the forwarded scheme must be
        // trusted, otherwise generated download URLs come out as http://. This
        // is opt-in through TRUSTED_PROXIES so a direct deployment never trusts
        // a spoofable X-Forwarded-* header.
        // env() rather than config(): the container is not bound yet when this
        // closure is registered.
        $proxies = env('TRUSTED_PROXIES', '');

        if (is_string($proxies) && $proxies !== '') {
            $middleware->trustProxies(at: $proxies === '*' ? '*' : explode(',', $proxies));
        }

        $middleware->alias([
            'force.json' => ForceJsonResponse::class,
            'log.api' => LogApiRequests::class,
            'verified' => EnsureEmailVerified::class,
            'staff' => EnsureStaff::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
