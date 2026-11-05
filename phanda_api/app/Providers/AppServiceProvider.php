<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\OtpSender;
use App\Contracts\PaymentGateway;
use App\Contracts\PushSender;
use App\Services\EntitlementService;
use App\Services\OtpService;
use App\Services\PayChanguGateway;
use App\Services\Push\FirebasePushSender;
use App\Services\Push\NullPushSender;
use App\Services\Push\PushDispatcher;
use App\Services\WhatsApp\CloudApiOtpSender;
use App\Services\WhatsApp\NullOtpSender;
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

        // Phone sign-in. Without credentials this is a null sender: the endpoint
        // answers 503 and says why, instead of queueing codes into the void.
        $this->app->singleton(OtpSender::class, function (): OtpSender {
            $phoneNumberId = (string) config('services.whatsapp.phone_number_id', '');
            $token = (string) config('services.whatsapp.token', '');
            $template = (string) config('services.whatsapp.template', '');

            if ($phoneNumberId === '' || $token === '' || $template === '') {
                return new NullOtpSender();
            }

            return new CloudApiOtpSender(
                $phoneNumberId,
                $token,
                $template,
                (string) config('services.whatsapp.language', 'en_US'),
                (string) config('services.whatsapp.version', 'v21.0'),
                (bool) config('services.whatsapp.code_button', true),
            );
        });

        $this->app->singleton(OtpService::class);
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

        // Sign-in codes: start, resend, and a mistyped digit all hit these two
        // routes, so 5/min is too tight to sign in. The per-number limits that
        // actually stop abuse live in OtpService; this only caps a single host
        // cycling numbers.
        RateLimiter::for('otp', fn (Request $request) => Limit::perMinute(12)->by($request->ip()));

        // Authenticated user requests - higher limit
        RateLimiter::for('authenticated', fn (Request $request) => $request->user()
            ? Limit::perMinute(120)->by($request->user()->id)
            : Limit::perMinute(60)->by($request->ip()));
    }
}
