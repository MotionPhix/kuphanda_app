"""Layout regressions, written against real papers.

Each case is the text of one paper family, verbatim as the text layer gives it.
When a layout fails in the corpus the paper is added here, so the fix cannot be
undone by the next change.

    python -m unittest test_layouts -v
"""

import unittest

import exam_parser as ep


# Saint Mary's / Chimbaza mock, Geography Paper II. Distinctive traits: the
# allocation sits at the end of a ruled answer line, roman labels appear as
# "(i)." and as a bare "i." with its text on the next line, and numbered
# sub-items ("1. Fractioning") live inside a roman part.
CHIMBAZA = [
    '1. a. (i). Define the term "Natural Resources"?',
    "_____________________________________________(1mark)",
    "(ii). Differentiate between renewable and nonrenewable resources?",
    "____________________________________________(2marks)",
    "b. Figure 1 shows a process of energy production. Use it to answer questions that",
    "follow.",
    "i.",
    "Name the parts labelled A and B?",
    "_______________________________________(2marks)",
    "ii.",
    "What type of energy is produced in figure 1?",
    "________________________________________(1mark)",
    "d. i. Describe the following processes in oil refining.",
    "1. Fractioning",
    "_____________________________________________(2marks)",
    "2. Creaking",
    "_____________________________________________(2marks)",
    "ii. Imagine that oil reserve have been discovered in Lake Malawi. Explain any two",
    "reasons why the government would want to exploit the mineral oil.",
    "_____________________________________________(4marks)",
    "2. a. Figure 2 is a population pyramid. Use it to answer questions that follow.",
    "i.",
    "Which group of countries in relation to the economy are represented by the",
    "population pyramid?",
    "________________________________________(1mark)",
    "ii.",
    "Explain why the population pyramid above has",
    "1. Broad base",
    "____________________________________________________(2marks)",
    "2. Narrow apex",
    "____________________________________________________(2marks)",
    "b. i. Explain why the Nile valley in Africa has high population.",
    "_____________________________________________________(2marks)",
    "ii. Suggest two strategies for controlling population growth in Malawi?",
    "______________________________________________________(2marks)",
]


class ChimbazaLayoutTests(unittest.TestCase):
    def setUp(self):
        self.questions = ep.parse_questions(CHIMBAZA)

    def test_every_question_is_found(self):
        self.assertEqual([q["label"] for q in self.questions], ["1.", "2."])

    def test_ruled_answer_lines_do_not_become_text(self):
        first = self.questions[0]["parts"][0]["parts"][0]

        self.assertEqual(first["text"], 'Define the term "Natural Resources"?')

    def test_roman_label_with_a_trailing_dot_is_clean(self):
        labels = [p["label"] for p in self.questions[0]["parts"][0]["parts"]]

        self.assertEqual(labels, ["(i)", "(ii)"])

    def test_bare_roman_label_takes_the_next_line(self):
        parts = self.questions[0]["parts"][1]["parts"]

        self.assertEqual(parts[0]["label"], "i.")
        self.assertEqual(parts[0]["text"], "Name the parts labelled A and B?")

    def test_numbered_sub_items_hang_under_the_roman_part(self):
        oil = self.questions[0]["parts"][2]["parts"][0]

        self.assertEqual([c["label"] for c in oil["parts"]], ["1.", "2."])
        self.assertEqual([c["marks"] for c in oil["parts"]], [2, 2])
        self.assertIsNone(oil["marks"])

    def test_a_sub_item_is_not_mistaken_for_the_next_question(self):
        # "2. Creaking" must not open question 2.
        self.assertEqual(ep.question_marks(self.questions[0]), 14)
        self.assertEqual(ep.question_marks(self.questions[1]), 9)

    def test_totals_add_up(self):
        self.assertEqual(sum(ep.question_marks(q) for q in self.questions), 23)
