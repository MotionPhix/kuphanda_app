"""Tests for table recovery from word positions.

    python -m unittest test_table_parser -v
"""

import unittest

import table_parser as tp


def word(x0, y0, text, width=20.0):
    return (x0, y0, x0 + width, y0 + 9.0, text, 0, 0, 0)


class GroupRowsTests(unittest.TestCase):
    def test_words_on_one_line_become_cells_split_by_gaps(self):
        rows = tp.group_rows([
            word(72.0, 100.0, "Produce"),
            word(283.0, 100.0, "Farm"),
            word(310.0, 100.0, "gate"),
            word(424.0, 100.0, "Retail"),
        ])

        self.assertEqual(len(rows), 1)
        self.assertEqual([text for _, text in rows[0]["cells"]],
                         ["Produce", "Farm gate", "Retail"])

    def test_nearby_lines_are_separate_rows(self):
        rows = tp.group_rows([
            word(72.0, 100.0, "one"),
            word(72.0, 114.0, "two"),
        ])

        self.assertEqual(len(rows), 2)


class MergeWrappedTests(unittest.TestCase):
    def test_wrapped_header_is_folded_into_its_cell(self):
        rows = tp.merge_wrapped([
            {"y": 197.9, "cells": [(190.9, "Produce"), (283.0, "Farm gate price (MK/kg)"), (424.8, "Retail Price")]},
            {"y": 211.7, "cells": [(424.8, "(MK/kg)")]},
        ])

        self.assertEqual(len(rows), 1)
        self.assertEqual([text for _, text in rows[0]["cells"]],
                         ["Produce", "Farm gate price (MK/kg)", "Retail Price (MK/kg)"])

    def test_a_short_row_that_does_not_align_is_kept(self):
        rows = tp.merge_wrapped([
            {"y": 100.0, "cells": [(72.0, "a"), (283.0, "b"), (424.0, "c")]},
            {"y": 114.0, "cells": [(90.0, "caption")]},
        ])

        self.assertEqual(len(rows), 2)

    def test_a_full_width_row_is_not_folded(self):
        rows = tp.merge_wrapped([
            {"y": 100.0, "cells": [(72.0, "a"), (283.0, "b")]},
            {"y": 114.0, "cells": [(72.0, "c"), (283.0, "d")]},
        ])

        self.assertEqual(len(rows), 2)


class DetectTablesTests(unittest.TestCase):
    def test_farm_gate_price_table(self):
        words = [
            # Question stem
            word(72.0, 146.0, "7."), word(90.0, 146.0, "Table"), word(125.0, 146.0, "1"),
            # Header, with the second header line wrapped
            word(190.9, 197.9, "Produce", 50.0),
            word(283.0, 197.9, "Farm", 32.0), word(314.6, 197.9, "gate", 25.0),
            word(338.8, 197.9, "price", 26.0), word(367.8, 197.9, "(MK/kg)", 45.0),
            word(424.8, 197.9, "Retail", 30.0), word(479.5, 197.9, "Price", 26.0),
            word(424.8, 211.7, "(MK/kg)", 45.0),
            # Body rows
            word(190.9, 226.0, "Irish", 25.0), word(215.7, 226.0, "potatoes", 40.0),
            word(283.0, 226.0, "350.00", 33.0), word(424.8, 226.0, "700.00", 33.0),
            word(190.9, 240.4, "Cabbages", 47.0),
            word(283.0, 240.4, "80.50", 27.0), word(424.8, 240.4, "180.75", 33.0),
            word(190.9, 254.7, "Onions", 35.0),
            word(283.0, 254.7, "600.00", 33.0), word(424.8, 254.7, "750.00", 33.0),
            # Next part label, outside the table
            word(101.7, 269.0, "i."), word(126.0, 269.0, "Calculate"),
        ]

        tables = tp.detect_tables(words)

        self.assertEqual(len(tables), 1)

        rows = tp.normalise(tables[0]["rows"])

        self.assertEqual(rows[0], ["Produce", "Farm gate price (MK/kg)", "Retail Price (MK/kg)"])
        self.assertEqual(rows[1], ["Irish potatoes", "350.00", "700.00"])
        self.assertEqual(rows[2], ["Cabbages", "80.50", "180.75"])
        self.assertEqual(rows[3], ["Onions", "600.00", "750.00"])

    def test_prose_with_normal_spacing_is_not_a_table(self):
        words = [
            word(72.0, 100.0, "Answer"), word(110.0, 100.0, "all"), word(125.0, 100.0, "the"),
            word(145.0, 100.0, "questions"), word(200.0, 100.0, "in"), word(215.0, 100.0, "this"),
            word(72.0, 114.0, "section."),
            word(72.0, 128.0, "Write"), word(110.0, 128.0, "your"), word(145.0, 128.0, "name."),
        ]

        self.assertEqual(tp.detect_tables(words), [])

    def test_two_rows_are_not_enough(self):
        words = [
            word(72.0, 100.0, "a"), word(300.0, 100.0, "b"),
            word(72.0, 114.0, "c"), word(300.0, 114.0, "d"),
        ]

        self.assertEqual(tp.detect_tables(words), [])


class NormaliseTests(unittest.TestCase):
    def test_ragged_rows_are_padded(self):
        self.assertEqual(tp.normalise([["a", "b"], ["c"]]), [["a", "b"], ["c", ""]])


if __name__ == "__main__":
    unittest.main()

class ListVersusTableTests(unittest.TestCase):
    def test_two_column_bullet_list_is_not_a_table(self):
        words = [
            word(120.0, 100.0, "•", 4.0), word(150.0, 100.0, "Farm", 30.0),
            word(184.0, 100.0, "settlement", 55.0), word(243.0, 100.0, "program", 45.0),
            word(120.0, 114.0, "•", 4.0), word(150.0, 114.0, "Subsidy", 42.0),
            word(196.0, 114.0, "program", 45.0),
            word(120.0, 128.0, "•", 4.0), word(150.0, 128.0, "Soil", 24.0),
            word(178.0, 128.0, "testing", 38.0), word(220.0, 128.0, "unit", 22.0),
        ]

        self.assertEqual(tp.detect_tables(words), [])

    def test_two_column_price_table_is_a_table(self):
        words = [
            word(120.0, 100.0, "Item", 30.0), word(400.0, 100.0, "Cost", 30.0),
            word(120.0, 114.0, "Seed", 28.0), word(400.0, 114.0, "K2,500", 40.0),
            word(120.0, 128.0, "Fertiliser", 55.0), word(400.0, 128.0, "K18,000", 48.0),
            word(120.0, 142.0, "Transport", 58.0), word(400.0, 142.0, "K4,000", 40.0),
        ]

        tables = tp.detect_tables(words)

        self.assertEqual(len(tables), 1)
        self.assertEqual(tp.normalise(tables[0]["rows"]), [
            ["Item", "Cost"],
            ["Seed", "K2,500"],
            ["Fertiliser", "K18,000"],
            ["Transport", "K4,000"],
        ])
