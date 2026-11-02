<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

final class ResetPasswordNotification extends Notification
{
    use Queueable;

    public function __construct(public readonly string $token) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        // A page, not an API call: the learner taps this on a phone and types a
        // new password. PASSWORD_RESET_URL points it at a web app instead when
        // one exists.
        $url = (string) config('app.password_reset_url');
        $url .= (str_contains($url, '?') ? '&' : '?').http_build_query([
            'token' => $this->token,
            'email' => $notifiable->getEmailForPasswordReset(),
        ]);

        return (new MailMessage)
            ->subject('Reset your Kuphanda password')
            ->greeting('Hello '.$notifiable->name.',')
            ->line('Someone asked to reset the password for this Kuphanda account. If that was you, choose a new one below.')
            ->action('Choose a new password', $url)
            ->line('The link works for 60 minutes, and only once.')
            ->line('If you did not ask for this, ignore this email — the password stays as it is.')
            ->salutation('— The Kuphanda team');
    }
}

