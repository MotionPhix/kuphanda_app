<?php

declare(strict_types=1);

use App\Http\Middleware\EnsureEmailVerified;
use App\Http\Middleware\EnsureStaff;
use App\Http\Middleware\EnsureTeacher;
use App\Http\Middleware\ForceJsonResponse;
use App\Http\Middleware\LogApiRequests;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

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
            'teacher' => EnsureTeacher::class,
        ]);

        // There is no login route to redirect a guest to — this app is API
        // only. Left alone, Authenticate resolves route('login') first and
        // throws RouteNotFoundException, so any unauthenticated call without
        // "Accept: application/json" became a 500 blaming a missing route.
        $middleware->redirectGuestsTo(
            fn (Request $request): ?string => $request->is('api/*') ? null : '/login'
        );
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Authenticate redirects a guest to route('login') unless the request
        // expects JSON. This app is API-only, so that route does not exist: a
        // request that merely omits "Accept: application/json" got a 500 whose
        // stack trace pointed at a missing login route, hiding the real answer
        // (401). Answer the API as JSON whatever header the client sent.
        $exceptions->render(function (AuthenticationException $e, Request $request): ?JsonResponse {
            if (! $request->is('api/*')) {
                return null;
            }

            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
            ], Response::HTTP_UNAUTHORIZED);
        });
    })->create();

