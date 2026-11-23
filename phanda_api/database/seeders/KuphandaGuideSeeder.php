<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Document;
use Illuminate\Database\Seeder;

/**
 * Rewrites "How to use Kuphanda" as a structured block document.
 *
 * The guide shipped as a PDF written before sign-in existed: it told learners
 * there was no login wall and had no mention of subscriptions, downloads or the
 * device storage budget. On a phone that PDF was the worst possible first read,
 * because the one document explaining the app was the only one that could not
 * reflow.
 *
 * It is now seven short screens with the same block vocabulary as the
 * transcribed paper, so it uses the structured reader, wraps at any width and
 * keeps the pager. Text is deliberately plain: this is read by a Form 1 learner
 * on a 5-inch screen, not by a developer.
 *
 * Idempotent: re-running replaces the blocks and drops any stale PDF versions,
 * media and offline marks that pointed at them.
 */
final class KuphandaGuideSeeder extends Seeder
{
    private const GUIDE_ID = 'sample-howto';

    public function run(): void
    {
        $guide = Document::query()->find(self::GUIDE_ID);

        if ($guide === null) {
            $this->command?->warn('Guide skipped: '.self::GUIDE_ID.' is not in the catalogue.');

            return;
        }

        // The old editions are PDFs; keeping them would leave learners holding a
        // file whose instructions no longer match the app.
        $guide->clearMediaCollection('files');
        $guide->versions()->delete();

        $guide->forceFill([
            'format' => 'blocks',
            'blocks' => [
                'subtitle' => 'Everything the app does, in seven short screens',
                'blocks' => $this->blocks(),
            ],
            'pages' => 7,
            'latest_version' => 0,
            'is_published' => true,
            'access_tier' => 'free',
            'content_updated_at' => now(),
        ])->save();

        $this->command?->info('Rewrote '.self::GUIDE_ID.' as a seven-page block guide.');
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function blocks(): array
    {
        return [
            ['type' => 'heading', 'page' => 1, 'text' => 'Kuphanda in one minute'],
            ['type' => 'paragraph', 'page' => 1, 'text' => 'Kuphanda is a school library in your pocket: past papers, notes and study guides for Forms 1 to 4, on a phone, with or without a connection.'],
            ['type' => 'bullets', 'page' => 1, 'items' => [
                'Free papers open for everyone, permanently.',
                'A subscription unlocks every premium paper and study guide.',
                'Anything you download keeps working when the signal does not.',
            ]],

            ['type' => 'heading', 'page' => 2, 'text' => 'Signing in'],
            ['type' => 'paragraph', 'page' => 2, 'text' => 'Your papers, classes and progress belong to your account, so start by signing in.'],
            ['type' => 'bullets', 'page' => 2, 'items' => [
                'Google is the quickest route — one tap, no password to remember.',
                'Use the email your school gave you if it is already registered.',
                'Signing in with a phone number arrives once Meta approves the business account.',
            ]],

            ['type' => 'heading', 'page' => 3, 'text' => 'Finding what you need'],
            ['type' => 'paragraph', 'page' => 3, 'text' => 'The library is organised by subject, then by form and paper.'],
            ['type' => 'bullets', 'page' => 3, 'items' => [
                'Filter by form, paper or year to narrow a subject down.',
                'Search by title when you already know what you want.',
                'A lock on a paper means it needs a subscription or a single purchase.',
            ]],

            ['type' => 'heading', 'page' => 4, 'text' => 'Free, and what a subscription adds'],
            ['type' => 'paragraph', 'page' => 4, 'text' => 'Free papers stay free. A subscription removes the locks on everything else, and you can also buy one paper on its own if that is all you need.'],
            ['type' => 'bullets', 'page' => 4, 'items' => [
                'Pay with mobile money through PayChangu.',
                'A single purchase unlocks that paper for good.',
                'Your access is checked when you open a paper, so it follows your account across devices.',
            ]],

            ['type' => 'heading', 'page' => 5, 'text' => 'Reading without a connection'],
            ['type' => 'paragraph', 'page' => 5, 'text' => 'Open a paper and tap Download to keep it on this phone. It stays readable in a classroom with no signal.'],
            ['type' => 'bullets', 'page' => 5, 'items' => [
                'Downloads share 50 MB on this device.',
                'When that space fills, the papers you opened longest ago are removed first.',
                'The library shows how much space is in use, and any removal is explained.',
                'Remove a download yourself from the paper page whenever you like.',
            ]],

            ['type' => 'heading', 'page' => 6, 'text' => 'Your progress'],
            ['type' => 'paragraph', 'page' => 6, 'text' => 'Pages read and minutes studied are recorded as you go, not ticked off by hand.'],
            ['type' => 'bullets', 'page' => 6, 'items' => [
                'Your streak counts the days you opened something.',
                'Teachers see class progress from their own account.',
                'Progress is tied to your account, so it survives a new phone.',
            ]],

            ['type' => 'heading', 'page' => 7, 'text' => 'When something goes wrong'],
            ['type' => 'paragraph', 'page' => 7, 'text' => 'Most failures are the connection rather than the app. Check that other apps can reach the internet, then try again.'],
            ['type' => 'bullets', 'page' => 7, 'items' => [
                'If only Kuphanda fails, sign out and back in to refresh your session.',
                'If a download stops, the paper stays in the library and can be retried.',
                'Still stuck? Tell your school office which paper and what the message said.',
            ]],
        ];
    }
}
