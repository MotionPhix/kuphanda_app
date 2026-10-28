<?php

declare(strict_types=1);

namespace App\Services\Push;

use App\Contracts\PushSender;
use App\Models\DeviceToken;
use App\Models\DocumentPurchase;
use App\Models\PushMessage;
use App\Models\Subscription;
use App\Models\User;

/**
 * Turns an intent ("tell Form 3 about the new paper", "confirm a payment") into
 * a recorded message and a delivery attempt.
 *
 * Broadcasts go to FCM topics so the cost stays constant as the audience grows;
 * transactional messages go to the account's own device tokens.
 */
final class PushDispatcher
{
    public const AUDIENCE_ALL = 'all';

    public const AUDIENCE_STUDENTS = 'students';

    public const AUDIENCE_TEACHERS = 'teachers';

    public const AUDIENCE_FORM = 'form';

    public const AUDIENCE_USER = 'user';

    public function __construct(private readonly PushSender $sender) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function broadcast(
        string $audience,
        ?string $audienceValue,
        string $category,
        string $title,
        string $body,
        array $data = [],
        ?User $sender = null,
    ): PushMessage {
        $topic = $this->topicFor($audience, $audienceValue);

        $delivered = $this->sender->sendToTopic($topic, [
            'title' => $title,
            'body' => $body,
            'data' => ['category' => $category] + $data,
        ]);

        return PushMessage::query()->create([
            'sent_by' => $sender?->id,
            'audience' => $audience,
            'audience_value' => $audienceValue,
            'category' => $category,
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'delivered' => $delivered ? 1 : 0,
            'failed' => $delivered ? 0 : 1,
        ]);
    }

    /**
     * Sends to every device the account has registered. Returns how many
     * devices accepted the message.
     *
     * @param  array<string, mixed>  $data
     */
    public function toUser(
        User $user,
        string $category,
        string $title,
        string $body,
        array $data = [],
    ): int {
        $tokens = DeviceToken::query()
            ->where('user_id', $user->id)
            ->pluck('token');

        if ($tokens->isEmpty()) {
            return 0;
        }

        $delivered = 0;
        $failed = 0;

        foreach ($tokens as $token) {
            $ok = $this->sender->sendToToken($token, [
                'title' => $title,
                'body' => $body,
                'data' => ['category' => $category] + $data,
            ]);

            if ($ok) {
                $delivered++;
            } else {
                $failed++;
            }
        }

        PushMessage::query()->create([
            'audience' => self::AUDIENCE_USER,
            'audience_value' => (string) $user->id,
            'category' => $category,
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'delivered' => $delivered,
            'failed' => $failed,
        ]);

        return $delivered;
    }

    public function subscriptionActivated(Subscription $subscription): void
    {
        $user = $subscription->user;
        $plan = $subscription->plan;

        if ($user === null || $plan === null) {
            return;
        }

        $until = $subscription->ends_at?->format('j M Y') ?? 'your next renewal';

        $this->toUser(
            $user,
            'subscription',
            'Your '.$plan->name.' is active',
            'You can now read every covered document until '.$until.'.',
            [
                'plan' => $plan->name,
                'tx_ref' => $subscription->tx_ref,
                'route' => 'subscription',
            ],
        );
    }

    public function purchaseCompleted(DocumentPurchase $purchase): void
    {
        $user = $purchase->user;
        $document = $purchase->document;

        if ($user === null || $document === null) {
            return;
        }

        $this->toUser(
            $user,
            'subscription',
            'Purchase confirmed',
            $document->title.' is now in your library.',
            [
                'document_id' => (string) $document->id,
                'route' => 'document',
            ],
        );
    }

    public function subscriptionExpiring(Subscription $subscription, int $daysLeft): void
    {
        $user = $subscription->user;
        $plan = $subscription->plan;

        if ($user === null || $plan === null || $subscription->ends_at === null) {
            return;
        }

        $when = $daysLeft <= 0 ? 'today' : 'in '.$daysLeft.' day'.($daysLeft === 1 ? '' : 's');

        $this->toUser(
            $user,
            'subscription',
            'Your pass expires '.$when,
            'Renew to keep reading premium papers after '.$subscription->ends_at->format('j M Y').'.',
            [
                'plan' => $plan->name,
                'tx_ref' => $subscription->tx_ref,
                'route' => 'subscription',
            ],
        );
    }

    public function topicFor(string $audience, ?string $audienceValue): string
    {
        return match ($audience) {
            self::AUDIENCE_STUDENTS => 'students',
            self::AUDIENCE_TEACHERS => 'teachers',
            self::AUDIENCE_FORM => 'form-'.(int) $audienceValue,
            default => 'all',
        };
    }
}
