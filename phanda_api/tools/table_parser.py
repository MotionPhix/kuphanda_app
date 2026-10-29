"""Recover tables from a PDF's word positions.

Papers are full of small tables — farm-gate vs retail prices, yields, costs —
and a question that says "Table 1 shows..." is unusable without them. A text
layer keeps every cell's coordinates, so the table can be rebuilt from geometry
instead of guessed from text order.

Everything here is a pure function over word boxes, so the rules are testable
without a PDF.
"""

from __future__ import annotations

from collections import Counter
from typing import Iterable, Sequence

#: Words this far apart vertically belong to different rows.
ROW_TOLERANCE = 2.5

#: A horizontal gap wider than this separates two cells. Ordinary word spacing
#: stays well under it, which is what stops a sentence splitting into columns.
CELL_GAP = 10.0

#: A wrapped cell must sit within this many points of the cell above it.
COLUMN_TOLERANCE = 8.0

#: Wrapped text stays within one line height of the line it continues.
WRAP_GAP = 20.0


Word = Sequence


def group_rows(words: Iterable[Word]) -> list[dict]:
    """Cluster words into rows, then rows into cells.

    Returns ``[{"y": float, "cells": [(x0, text), ...]}, ...]``.
    """
    ordered = sorted(words, key=lambda word: (round(float(word[1]), 1), float(word[0])))

    rows: list[dict] = []

    for word in ordered:
        x0, y0, x1 = float(word[0]), float(word[1]), float(word[2])
        text = str(word[4])

        if rows and abs(y0 - rows[-1]["y"]) <= ROW_TOLERANCE:
            rows[-1]["items"].append((x0, x1, text))
            continue

        rows.append({"y": y0, "items": [(x0, x1, text)]})

    for row in rows:
        cells: list[list] = []

        for x0, x1, text in sorted(row["items"]):
            if cells and x0 - cells[-1][1] <= CELL_GAP:
                cells[-1][1] = x1
                cells[-1][2].append(text)
                continue
            cells.append([x0, x1, [text]])

        row["cells"] = [(cell[0], " ".join(cell[2])) for cell in cells]
        del row["items"]

    return rows


def merge_wrapped(rows: list[dict]) -> list[dict]:
    """Fold a continuation line into the cell it continues.

    ``Retail / Price / (MK/kg)`` arrives as two rows. A row is a continuation
    when it has fewer cells than the one above, sits a line-height below, and
    every cell lines up with a cell above it.
    """
    merged: list[dict] = []

    for row in rows:
        if merged:
            previous = merged[-1]
            aligned = all(
                any(abs(x0 - above_x0) <= COLUMN_TOLERANCE for above_x0, _ in previous["cells"])
                for x0, _ in row["cells"]
            )
            short = len(row["cells"]) < len(previous["cells"])
            close = 0 < row["y"] - previous["y"] <= WRAP_GAP

            if aligned and short and close and row["cells"]:
                for x0, text in row["cells"]:
                    previous["cells"] = [
                        (above_x0, f"{above_text} {text}".strip())
                        if abs(x0 - above_x0) <= COLUMN_TOLERANCE
                        else (above_x0, above_text)
                        for above_x0, above_text in previous["cells"]
                    ]
                continue

        merged.append({"y": row["y"], "cells": list(row["cells"])})

    return merged


def _runs(rows: list[dict], min_columns: int) -> list[list[dict]]:
    """Consecutive rows that start at the same left edge."""
    runs: list[list[dict]] = []
    current: list[dict] = []

    def continues_above(row: dict) -> bool:
        """A wrapped line belongs to the table even though it has one cell."""
        if not current or not row["cells"]:
            return False

        above = current[-1]
        close = 0 < row["y"] - above["y"] <= WRAP_GAP
        aligned = all(
            any(abs(x0 - above_x0) <= COLUMN_TOLERANCE for above_x0, _ in above["cells"])
            for x0, _ in row["cells"]
        )

        return close and aligned

    for row in rows:
        if len(row["cells"]) >= min_columns:
            if current and abs(row["cells"][0][0] - current[0]["cells"][0][0]) <= COLUMN_TOLERANCE:
                current.append(row)
                continue

            if current:
                runs.append(current)

            current = [row]
            continue

        if current and continues_above(row):
            current.append(row)
            continue

        if current:
            runs.append(current)

        current = []

    if current:
        runs.append(current)

    return runs


def _anchors(run: list[dict], width: int) -> list[float] | None:
    """Column positions, taken from the rows that already agree on the width."""
    steady = [row for row in run if len(row["cells"]) == width]

    if not steady:
        return None

    columns: list[list[float]] = [[] for _ in range(width)]

    for row in steady:
        for index, (x0, _) in enumerate(sorted(row["cells"])[:width]):
            columns[index].append(x0)

    return sorted(sum(column) / len(column) for column in columns)


def _fit(row: dict, anchors: list[float]) -> dict:
    """Snap a row onto the table's columns.

    A header cell like "Retail Price" can be split in two by the gap rule when
    the cell is centred, so words are re-assigned to the columns the body rows
    established rather than trusted as cells.
    """
    texts = ["" for _ in anchors]

    for x0, text in row["cells"]:
        index = 0

        for position, anchor in enumerate(anchors):
            if x0 >= anchor - COLUMN_TOLERANCE:
                index = position

        texts[index] = f"{texts[index]} {text}".strip()

    return {
        "y": row["y"],
        "cells": [(anchors[i], texts[i]) for i in range(len(anchors)) if texts[i]],
    }


def _carries_values(rows: list[dict]) -> bool:
    """At least half the body rows hold a number."""
    body = rows[1:]

    if not body:
        return False

    numeric = sum(
        1
        for row in body
        if any(any(character.isdigit() for character in text) for _, text in row["cells"])
    )

    return numeric * 2 >= len(body)


def detect_tables(words: Iterable[Word], min_rows: int = 3, min_columns: int = 2) -> list[dict]:
    """Find runs of rows whose columns line up.

    Returns ``[{"y0": float, "y1": float, "row_ys": [...], "rows": [[cell, ...], ...]}]``.
    The first row is the header, matching how ``_TableBlock`` renders it.
    """
    rows = group_rows(words)
    tables: list[dict] = []

    for run in _runs(rows, min_columns):
        widths = Counter(len(row["cells"]) for row in run)
        width = widths.most_common(1)[0][0]

        if width < min_columns:
            continue

        anchors = _anchors(run, width)

        if anchors is None:
            continue

        fitted = merge_wrapped([_fit(row, anchors) for row in run])

        if len(fitted) < min_rows:
            continue

        # Two columns of prose are a bulleted list, not a table: a real
        # two-column table carries values ("Item | Price").
        if width < 3 and not _carries_values(fitted):
            continue

        tables.append({
            "y0": fitted[0]["y"],
            "y1": fitted[-1]["y"],
            "row_ys": [row["y"] for row in fitted],
            "rows": [[text for _, text in row["cells"]] for row in fitted],
        })

    return tables


def normalise(rows: list[list[str]]) -> list[list[str]]:
    """Pad ragged rows so every row has the same number of cells."""
    width = max((len(row) for row in rows), default=0)

    return [row + [""] * (width - len(row)) for row in rows]
