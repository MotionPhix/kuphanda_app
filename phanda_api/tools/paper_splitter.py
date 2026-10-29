"""Split a composite PDF into separate papers and marking schemes.

Most files in the corpus are not one paper. They hold Paper I and Paper II, or a
paper followed by its marking scheme, or three years of one subject. Parsing such
a file whole produces a document that fails the audit for the right reason: the
marks belong to two different papers.

This works on per-page text from a text layer, so it is a pure function and can
be tested without a PDF.

    segments = split_papers([page_one_text, page_two_text, ...])
"""

from __future__ import annotations

import re
from typing import Sequence

#: Roman numerals that arrive as their own codepoints in downloaded papers.
_ROMAN = {"Ⅰ": "I", "Ⅱ": "II", "Ⅲ": "III", "ⅰ": "I", "ⅱ": "II"}

_SCHEME = (
    re.compile(r"\bMARK(?:ING)?\s+SCHEME\b"),
    re.compile(r"\bSCHEME\s+OF\s+MARK(?:ING|S)?\b"),
    re.compile(r"\bMARKING\s+GUIDE\b"),
    re.compile(r"\bSOLUTIONS?\s+(?:TO|FOR)\b"),
)

_PAPER_1 = (
    re.compile(r"\bPAPER\s*(?:I|1)\b(?!\s*I)"),
)

_PAPER_2 = (
    re.compile(r"\bPAPER\s*(?:II|2)\b"),
)

#: A paper states its own worth on the cover: "(100 marks)". OCR regularly
#: drops the r ("（100maks）"), so the letter class carries both forms.
_TOTAL = re.compile(r"\(?\s*(\d{2,3})\s*ma[rs]?ks?\s*\)?", re.IGNORECASE)


def normalise(text: str) -> str:
    for source, target in _ROMAN.items():
        text = text.replace(source, target)

    # OCR output is full of full-width punctuation and doubled spaces.
    text = text.replace("（", "(").replace("）", ")").replace("　", " ")

    return re.sub(r"[ \t]+", " ", text.upper())


def stated_marks(text: str) -> int | None:
    """The paper's own total, if the page prints one.

    Small allocations are per question, so only totals of 50 or more count.
    """
    for match in _TOTAL.finditer(normalise(text)):
        value = int(match.group(1))

        if 50 <= value <= 400:
            return value

    return None


def classify_page(text: str) -> tuple[str, int | None] | None:
    """What one page says about itself, or None when it only continues."""
    page = normalise(text)

    if any(pattern.search(page) for pattern in _SCHEME):
        return ("scheme", None)

    if any(pattern.search(page) for pattern in _PAPER_2):
        return ("paper", 2)

    if any(pattern.search(page) for pattern in _PAPER_1):
        return ("paper", 1)

    return None


def split_papers(pages: Sequence[str]) -> list[dict]:
    """Group consecutive pages that belong to the same paper or scheme.

    Returns segments with 1-based, inclusive page ranges. Pages that only
    continue the previous one inherit its identity; pages before any marker are
    reported as unknown rather than guessed at.
    """
    segments: list[dict] = []

    for index, text in enumerate(pages, start=1):
        found = classify_page(text)
        kind, paper = found if found else (None, None)

        current = segments[-1] if segments else None

        if current is None:
            segments.append(
                {"kind": kind or "unknown", "paper": paper, "start": index, "end": index}
            )

            continue

        # A new marker starts a segment; a page without one continues the run.
        starts_new = kind is not None and (kind != current["kind"] or paper != current["paper"])

        if starts_new:
            segments.append({"kind": kind, "paper": paper, "start": index, "end": index})

            continue

        current["end"] = index

    for segment in segments:
        segment["pages"] = segment["end"] - segment["start"] + 1

    return segments


def summarise(segments: Sequence[dict]) -> str:
    """One line per segment, for logs."""
    lines = []

    for segment in segments:
        paper = f" Paper {segment['paper']}" if segment["paper"] else ""

        lines.append(f"{segment['kind']}{paper} pages {segment['start']}-{segment['end']}")

    return " | ".join(lines)


def segments_worth_parsing(segments: Sequence[dict]) -> list[dict]:
    """Segments that describe an actual paper, not a scheme or unknown filler."""
    return [s for s in segments if s["kind"] == "paper"]
