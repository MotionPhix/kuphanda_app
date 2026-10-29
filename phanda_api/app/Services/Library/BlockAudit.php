<?php

declare(strict_types=1);

namespace App\Services\Library;

/**
 * Checks that a structured paper is internally consistent.
 *
 * A wrong mark total is worse than no total: a learner practises against it and
 * a teacher cannot score fairly. This reports rather than repairs, because only
 * a human knows whether a missing 2 marks belongs to part (b) or (c).
 */
final class BlockAudit
{
    /**
     * @param  array<int, array<string, mixed>>  $blocks
     * @return array{questions: int, marks: int, issues: list<string>}
     */
    public function inspect(array $blocks, ?string $subtitle = null): array
    {
        $questions = array_values(array_filter(
            $blocks,
            static fn (array $block): bool => ($block['type'] ?? null) === 'question'
        ));

        $sum = 0;
        $issues = [];

        foreach ($questions as $question) {
            $label = (string) ($question['label'] ?? '?');
            $parts = $question['parts'] ?? [];
            $partSum = 0;
            $missing = 0;

            // Marks belong to answer-bearing leaves. A part that only groups
            // sub-parts ("c. State any one way in which each of the following
            // ...") carries no mark of its own, and inventing one to satisfy a
            // total is exactly how a paper ends up wrong.
            foreach ($parts as $part) {
                $missing += $this->unmarkedLeaves($part);
                $partSum += $this->leafMarks($part);
            }

            $declared = isset($question['marks']) ? (int) $question['marks'] : null;

            if ($parts !== [] && $declared !== null && $partSum !== $declared) {
                $issues[] = sprintf('%s: parts total %d but question says %d', $label, $partSum, $declared);
            }

            if ($missing > 0) {
                $issues[] = sprintf('%s: %d part(s) without marks', $label, $missing);
            }

            if (trim((string) ($question['text'] ?? '')) === '') {
                $issues[] = sprintf('%s: empty stem', $label);
            }

            $sum += $declared ?? $partSum;
        }

        if ($subtitle !== null && preg_match('/(\d{2,3})\s*marks/', $subtitle, $match) === 1) {
            $expected = (int) $match[1];

            if ($sum !== $expected) {
                $issues[] = sprintf(
                    'total %d marks, document states %d (short by %d)',
                    $sum,
                    $expected,
                    $expected - $sum
                );
            }
        }

        return ['questions' => count($questions), 'marks' => $sum, 'issues' => $issues];
    }

    /**
     * Marks carried by one part, counting only answer-bearing leaves.
     *
     * @param  array<string, mixed>  $part
     */
    private function leafMarks(array $part): int
    {
        $children = $part['parts'] ?? [];

        if (is_array($children) && $children !== []) {
            $total = 0;

            foreach ($children as $child) {
                $total += is_array($child) ? $this->leafMarks($child) : 0;
            }

            return $total;
        }

        return (int) ($part['marks'] ?? 0);
    }

    /**
     * Leaves that should carry a mark but do not.
     *
     * @param  array<string, mixed>  $part
     */
    private function unmarkedLeaves(array $part): int
    {
        $children = $part['parts'] ?? [];

        if (is_array($children) && $children !== []) {
            $missing = 0;

            foreach ($children as $child) {
                $missing += is_array($child) ? $this->unmarkedLeaves($child) : 0;
            }

            return $missing;
        }

        return isset($part['marks']) ? 0 : 1;
    }
}
