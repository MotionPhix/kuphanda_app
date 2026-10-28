<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\PaymentGateway;
use App\Contracts\PushSender;
use App\Services\EntitlementService;
use App\Services\PayChanguGateway;
use App\Services\Push\FirebasePushSender;
use App\Services\Push\NullPushSender;
use App\Services\Push\PushDispatcher;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(PaymentGateway::class, PayChanguGateway::class);
        $this->app->singleton(EntitlementService::class);

        $this->app->singleton(PushSender::class, function (): PushSender {
            $project = (string) config('services.firebase.project_id', '');
            $credentials = (string) config('services.firebase.credentials', '');

            if ($project === '' || $credentials === '' || ! is_file($credentials)) {
                return new NullPushSender();
            }

            return new FirebasePushSender($project, $credentials);
        });

        $this->app->singleton(PushDispatcher::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    /**
     * Configure the rate limiters for the application.
     */
    private function configureRateLimiting(): void
    {
        // Default API rate limiter - 60 requests per minute
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(60)->by($request->user()?->id ?: $request->ip()));

        // Auth endpoints - more restrictive (prevent brute force)
        RateLimiter::for('auth', fn (Request $request) => Limit::perMinute(5)->by($request->ip()));

        // Authenticated user requests - higher limit
        RateLimiter::for('authenticated', fn (Request $request) => $request->user()
            ? Limit::perMinute(120)->by($request->user()->id)
            : Limit::perMinute(60)->by($request->ip()));
    }
}
