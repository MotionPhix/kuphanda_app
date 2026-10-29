"""Tests for the exam-paper structuring rules.

    python -m unittest test_exam_parser -v
"""

import unittest

import exam_parser as ep


class SplitMarksTests(unittest.TestCase):
    def test_trailing_marks_are_peeled_off(self):
        self.assertEqual(ep.split_marks("State two weeds. (2 marks)"), ("State two weeds.", 2))

    def test_singular_mark(self):
        self.assertEqual(ep.split_marks("Scarification (1 mark)"), ("Scarification", 1))

    def test_marks_alone_on_a_line(self):
        self.assertEqual(ep.split_marks("(2 marks)"), ("", 2))

    def test_no_marks(self):
        self.assertEqual(ep.split_marks("Mention any two beef breeds"), ("Mention any two beef breeds", None))


class ClassifyTests(unittest.TestCase):
    def test_lettered_label(self):
        self.assertEqual(ep.classify("a. State any two roles"), (ep.LETTERED, "a.", "State any two roles"))

    def test_bare_lettered_label_is_kept(self):
        self.assertEqual(ep.classify("c."), (ep.LETTERED, "c.", ""))

    def test_roman_with_dot(self):
        self.assertEqual(ep.classify("ii. Inoculation"), (ep.ROMAN, "ii.", "Inoculation"))

    def test_roman_in_brackets(self):
        self.assertEqual(ep.classify("(iii) Pelleting"), (ep.ROMAN, "(iii)", "Pelleting"))

    def test_bare_roman_label(self):
        self.assertEqual(ep.classify("i."), (ep.ROMAN, "i.", ""))

    def test_bracketed_number(self):
        self.assertEqual(ep.classify("(1) Irish potatoes"), (ep.BRACKETED, "(1)", "Irish potatoes"))

    def test_prose_starting_with_roman_letters_is_not_a_label(self):
        for prose in (
            "Identify the nutrient lacking in the crops.",
            "very slowly the water drained",
            "In the table provided on this page",
            "Is the soil fertile?",
            "various crops were planted",
        ):
            with self.subTest(prose=prose):
                self.assertIsNone(ep.classify(prose))

    def test_marks_line_is_not_a_label(self):
        self.assertIsNone(ep.classify("marks)"))
        self.assertEqual(ep.split_marks("(2 marks)"), ("", 2))


class ParsePartsTests(unittest.TestCase):
    def test_flat_lettered_parts(self):
        parts = ep.parse_parts([
            "a. State any two roles of estates. (2 marks)",
            "b. Explain any two ways. (4 marks)",
            "c. State any two factors. (2 marks)",
        ])

        self.assertEqual([p["label"] for p in parts], ["a.", "b.", "c."])
        self.assertEqual([p["marks"] for p in parts], [2, 4, 2])
        self.assertEqual(ep.total_marks(parts), 8)

    def test_roman_children_belong_to_the_preceding_lettered_part(self):
        parts = ep.parse_parts([
            "c. State any one way in which each of the following are avoided.",
            "i.",
            "Accidental self-pollination",
            "(1 mark)",
            "ii.",
            "Pollination by other foreign pollen.",
            "(1 mark)",
        ])

        self.assertEqual(len(parts), 1)
        parent = parts[0]
        self.assertEqual(parent["label"], "c.")
        self.assertIsNone(parent["marks"], "a container must not invent a mark")
        self.assertEqual([c["label"] for c in parent["parts"]], ["i.", "ii."])
        self.assertEqual([c["text"] for c in parent["parts"]],
                         ["Accidental self-pollination", "Pollination by other foreign pollen."])
        self.assertEqual(ep.total_marks(parts), 2)

    def test_three_levels_of_nesting(self):
        parts = ep.parse_parts([
            "i. Calculate the marketing margins for each of the following crops:",
            "(1) Irish potatoes",
            "(2 marks)",
            "(2) Onions.",
            "(2 marks)",
            "ii.",
            "(1) Which produce in (i) has the smaller marketing margin?",
            "(1 mark)",
            "(2) State any one possible cause of the difference.",
            "(1 mark)",
        ])

        self.assertEqual([p["label"] for p in parts], ["i.", "ii."])
        self.assertEqual([len(p["parts"]) for p in parts], [2, 2])
        self.assertEqual([c["label"] for c in parts[0]["parts"]], ["(1)", "(2)"])
        self.assertEqual([c["label"] for c in parts[1]["parts"]], ["(1)", "(2)"])
        self.assertEqual(ep.total_marks(parts), 6)

    def test_inline_first_part_on_the_question_line(self):
        parts = ep.parse_parts(["a. Mention any two beef breeds of cattle", "(2 marks)"])

        self.assertEqual(len(parts), 1)
        self.assertEqual(parts[0]["text"], "Mention any two beef breeds of cattle")
        self.assertEqual(parts[0]["marks"], 2)

    def test_inline_roman_on_a_lettered_line(self):
        parts = ep.parse_parts([
            "b. (i) Give any one reason why it is important.",
            "(1 mark)",
            "(ii) Describe any one cultural practice.",
            "(2 marks)",
        ])

        self.assertEqual(len(parts), 1)
        self.assertEqual(parts[0]["label"], "b.")
        self.assertEqual([c["label"] for c in parts[0]["parts"]], ["(i)", "(ii)"])
        self.assertEqual(parts[0]["parts"][0]["marks"], 1)
        self.assertEqual(parts[0]["parts"][1]["marks"], 2)
        self.assertEqual(ep.total_marks(parts), 3)

    def test_prose_lines_extend_the_current_part(self):
        parts = ep.parse_parts([
            "b. Explain any two ways in which farmers can achieve food self-sufficiency at household",
            "level.",
            "(4 marks)",
        ])

        self.assertEqual(parts[0]["text"],
                         "Explain any two ways in which farmers can achieve food self-sufficiency at household level.")
        self.assertEqual(parts[0]["marks"], 4)

    def test_marks_on_a_lettered_label_line(self):
        parts = ep.parse_parts(["a. State one safety measure. (1 mark)"])

        self.assertEqual(parts[0]["marks"], 1)

    def test_a_sibling_at_an_outer_level_closes_the_nest(self):
        parts = ep.parse_parts([
            "a. Importance of each:",
            "i.",
            "Scarification",
            "(1 mark)",
            "ii.",
            "Inoculation",
            "(1 mark)",
            "b. Explain one way:",
            "i.",
            "Method of sowing",
            "(2 marks)",
        ])

        self.assertEqual([p["label"] for p in parts], ["a.", "b."])
        self.assertEqual(len(parts[0]["parts"]), 2)
        self.assertEqual(len(parts[1]["parts"]), 1)
        self.assertEqual(ep.total_marks(parts), 4)


class LeafMarkTests(unittest.TestCase):
    def test_container_marks_are_ignored_when_children_exist(self):
        node = {"label": "a.", "marks": 5, "parts": [{"label": "i.", "marks": 2, "parts": []}]}

        self.assertEqual(ep.leaf_marks(node), 2)

    def test_leaf_without_marks_counts_zero(self):
        self.assertEqual(ep.leaf_marks({"label": "a.", "marks": None, "parts": []}), 0)


class ParseQuestionsTests(unittest.TestCase):
    def test_numbering_must_ascend_by_one(self):
        lines = [
            "2017. Mock examination",
            "1. First question",
            "a. part one (1 mark)",
            "3. Not the next question",
            "2. Second question",
            "a. part one (2 marks)",
        ]

        questions = ep.parse_questions(lines)

        self.assertEqual([q["label"] for q in questions], ["1.", "2."])
        self.assertEqual(len(questions[0]["parts"]), 1)
        self.assertEqual(ep.total_marks([p for q in questions for p in q["parts"]]), 3)

    def test_expected_total_is_enforced(self):
        lines = ["1. Question", "a. part (1 mark)"]

        with self.assertRaises(ValueError):
            ep.parse_questions(lines, expected_total=100)

    def test_expected_total_passes_when_it_matches(self):
        lines = ["1. Question", "a. part (1 mark)"]

        self.assertEqual(len(ep.parse_questions(lines, expected_total=1)), 1)


if __name__ == "__main__":
    unittest.main()

class UnlabelledQuestionTests(unittest.TestCase):
    def test_prose_question_keeps_its_allocation(self):
        lines = [
            "11. Explain how a farmer would prepare a seedbed for pasture.",
            "Include the tools used.",
            "(10 marks)",
        ]

        question = ep.parse_questions(lines, first_number=11)[0]

        self.assertEqual(question["parts"], [])
        self.assertEqual(question["marks"], 10)
        self.assertIn("prepare a seedbed", question["stem"])
        self.assertIn("Include the tools used.", question["stem"])

    def test_first_part_on_the_question_line(self):
        lines = ["2. a. Mention any two beef breeds of cattle", "(2 marks)"]

        question = ep.parse_questions(lines, first_number=2)[0]

        self.assertEqual(question["stem"], "")
        self.assertEqual([p["label"] for p in question["parts"]], ["a."])
        self.assertEqual(question["parts"][0]["marks"], 2)

class ReadingLinesTests(unittest.TestCase):
    def test_drops_page_furniture_and_ruled_space(self):
        text = "Name________________________________\nPage 3 of 6\nState two weeds.\n_______\nTurn over"

        self.assertEqual(ep.reading_lines(text), ["State two weeds."])

    def test_rejoins_an_allocation_split_over_two_lines(self):
        text = "Scarification\n(1\nmark)"

        self.assertEqual(ep.reading_lines(text), ["Scarification", "(1 mark)"])

    def test_keeps_the_wording_of_a_question(self):
        text = "Answer the following.\n2. a. Mention any two beef breeds"

        self.assertEqual(
            ep.reading_lines(text),
            ["Answer the following.", "2. a. Mention any two beef breeds"],
        )

    def test_furniture_check_tolerates_blank_lines(self):
        self.assertTrue(ep.is_furniture("   "))
        self.assertFalse(ep.is_furniture("13. Calculate the value of x."))

class SectionHeadingTests(unittest.TestCase):
    def test_section_heading_is_not_read_as_a_question_allocation(self):
        text = (
            "10. a. State any three functions of roots.\n(3 marks)\n"
            "Section B (40 marks)\n"
            "11. Explain any five roles of agro-based industries.\n(10 marks)"
        )

        questions = ep.parse_questions(ep.reading_lines(text), first_number=10)

        self.assertEqual([ep.question_marks(q) for q in questions], [3, 10])

    def test_reading_lines_drops_the_heading_itself(self):
        self.assertEqual(ep.reading_lines("Section A (60 marks)\n1. a. State"), ["1. a. State"])

class JoinedNumberingTests(unittest.TestCase):
    def test_letter_against_the_number_becomes_the_first_part(self):
        lines = ["1a. Give any two examples of matter.", "(2 marks)"]

        question = ep.parse_questions(lines, first_number=1)[0]

        self.assertEqual(question["label"], "1.")
        self.assertEqual([p["label"] for p in question["parts"]], ["a."])
        self.assertEqual(ep.question_marks(question), 2)

    def test_plain_numbering_still_reads_normally(self):
        lines = ["3. Table 1 shows some elements.", "(4 marks)"]

        question = ep.parse_questions(lines, first_number=3)[0]

        self.assertEqual(question["parts"], [])
        self.assertEqual(ep.question_marks(question), 4)

class ParenthesisedLetterTests(unittest.TestCase):
    def test_bracketed_letter_is_a_part_not_prose(self):
        lines = ["(a) i. What does the symbol stand for?", "(1 mark)"]

        parts = ep.parse_parts(lines)

        self.assertEqual(parts[0]["label"], "(a)")
        self.assertEqual(parts[0]["parts"][0]["label"], "i.")
        self.assertEqual(ep.leaf_marks(parts[0]), 1)

    def test_bracketed_roman_stays_roman(self):
        parts = ep.parse_parts(["(i) Accidental self-pollination", "(1 mark)"])

        self.assertEqual(parts[0]["label"], "(i)")

class JoinedPartLabelTests(unittest.TestCase):
    def test_letter_and_bracketed_roman_without_a_separator(self):
        # "5. a(i) Define the term transport?" — the letter hugs the roman.
        lines = ["5. a(i) Define the term transport?", "____(1mark)"]

        question = ep.parse_questions(lines, first_number=5)[0]
        part = question["parts"][0]

        self.assertEqual(part["label"], "a.")
        self.assertEqual(part["parts"][0]["label"], "(i)")
        self.assertEqual(part["parts"][0]["text"], "Define the term transport?")
        self.assertEqual(ep.question_marks(question), 1)
