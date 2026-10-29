"""Tests for splitting composite papers.

    python -m unittest test_paper_splitter -v
"""

import unittest

import paper_splitter as ps


COVER_1 = """
MALAWI SCHOOL CERTIFICATE OF EDUCATION EXAMINATION
MATHEMATICS                      PAPER I                  (100 marks)
"""

COVER_2 = """
MALAWI SCHOOL CERTIFICATE OF EDUCATION EXAMINATION
MATHEMATICS                      PAPER II                 (100 marks)
"""

SCHEME = """
MARKING SCHEME
MATHEMATICS PAPER I
"""


class ClassifyTests(unittest.TestCase):
    def test_cover_names_the_paper(self):
        self.assertEqual(ps.classify_page(COVER_1), ("paper", 1))
        self.assertEqual(ps.classify_page(COVER_2), ("paper", 2))

    def test_paper_two_is_not_read_as_paper_one(self):
        self.assertNotEqual(ps.classify_page(COVER_2), ("paper", 1))

    def test_marking_scheme_is_its_own_kind(self):
        self.assertEqual(ps.classify_page(SCHEME), ("scheme", None))

    def test_roman_numeral_codepoints_are_understood(self):
        self.assertEqual(ps.classify_page("MATHEMATICS PAPER Ⅱ (100 marks)"), ("paper", 2))

    def test_a_continuation_page_says_nothing(self):
        self.assertIsNone(ps.classify_page("13. Given that 2x, x, x+3 are terms in an AP."))

    def test_solutions_heading_counts_as_a_scheme(self):
        self.assertEqual(ps.classify_page("SOLUTIONS TO PAPER I"), ("scheme", None))


class StatedMarksTests(unittest.TestCase):
    def test_reads_the_cover_total(self):
        self.assertEqual(ps.stated_marks(COVER_1), 100)

    def test_ignores_per_question_allocations(self):
        self.assertIsNone(ps.stated_marks("Calculate the value of x. (3 marks)"))

    def test_handles_ocr_spacing(self):
        self.assertEqual(ps.stated_marks("MATHEMATICS PAPERI （100maks）"), 100)


class SplitTests(unittest.TestCase):
    def test_single_paper_stays_one_segment(self):
        segments = ps.split_papers([COVER_1, "Q1", "Q2", "Q3"])

        self.assertEqual(len(segments), 1)
        self.assertEqual(segments[0]["kind"], "paper")
        self.assertEqual(segments[0]["start"], 1)
        self.assertEqual(segments[0]["end"], 4)
        self.assertEqual(segments[0]["pages"], 4)

    def test_two_papers_in_one_file(self):
        segments = ps.split_papers([COVER_1, "Q1", COVER_2, "Q1"])

        self.assertEqual([s["paper"] for s in segments], [1, 2])
        self.assertEqual([s["start"] for s in segments], [1, 3])

    def test_paper_followed_by_its_scheme(self):
        segments = ps.split_papers([COVER_1, "Q1", SCHEME, "answer"])

        self.assertEqual([s["kind"] for s in segments], ["paper", "scheme"])
        self.assertEqual(segments[1]["start"], 3)
        self.assertEqual(segments[1]["end"], 4)

    def test_pages_before_any_marker_are_unknown_not_guessed(self):
        segments = ps.split_papers(["stray scan", COVER_1, "Q1"])

        self.assertEqual([s["kind"] for s in segments], ["unknown", "paper"])

    def test_unknown_run_is_kept_apart_from_the_marker(self):
        # A page with no marker is not assumed to belong to the paper that
        # follows it: guessing there would silently absorb stray covers.
        segments = ps.split_papers(["MATHEMATICS", "PAPER I (100 marks)", "Q1"])

        self.assertEqual([s["kind"] for s in segments], ["unknown", "paper"])
        self.assertEqual(len(ps.segments_worth_parsing(segments)), 1)

    def test_only_papers_are_offered_for_parsing(self):
        segments = ps.split_papers([COVER_1, "Q1", SCHEME, "answer"])

        self.assertEqual(len(ps.segments_worth_parsing(segments)), 1)

    def test_summary_is_readable(self):
        segments = ps.split_papers([COVER_1, "Q1", COVER_2, "Q1", SCHEME])

        self.assertEqual(
            ps.summarise(segments),
            "paper Paper 1 pages 1-2 | paper Paper 2 pages 3-4 | scheme pages 5-5",
        )


if __name__ == "__main__":
    unittest.main()
