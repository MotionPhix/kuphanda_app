"""Convert the 2017 Agriculture Paper 1 PDF into a block document.

This is the thin part: read the PDF, drop furniture and table cells from the
reading stream, and hand the lines to ``exam_parser``. The structuring rules and
the table geometry live there, with tests.

    python parse_agriculture.py --pdf paper.pdf           # write the blocks file
    python parse_agriculture.py --pdf paper.pdf --check   # parse only

The parse fails loudly if the leaves do not add up to the 100 marks the paper
states, so a silent mark loss cannot reach the seeder.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import pymupdf

import exam_parser as ep
import table_parser as tp

API_ROOT = Path(__file__).resolve().parents[1]

#: The scanned paper is not committed; point --pdf at a local copy.
DEFAULT_PDF = "msce-agriculture-paper-1-2017.pdf"

OUT = API_ROOT / "database/seeders/files/blocks-msce-agriculture-2017-p1.json"

#: Anything that is page furniture rather than paper content.
NOISE = re.compile(
    r"(Name_+|Page \d+ of \d+|Turn over|Continued|©|MZUZU|Answer all|"
    r"maximum number of marks|spaces provided|Write your name|"
    r"In the table provided|Hand in your paper|Answer the following)",
    re.IGNORECASE,
)

SECTION_START = re.compile(r"^Section\s+([AB])\s*\((\d+)\s*marks\)", re.IGNORECASE)

SPLIT_MARKS = re.compile(r"^\((\d+)$")
MARKS_TAIL = re.compile(r"^marks?\)$", re.IGNORECASE)


def page_lines(page) -> list[tuple[float, str]]:
    """``(y, text)`` for each line on a page, in reading order."""
    entries: list[tuple[float, str]] = []

    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            text = "".join(span.get("text", "") for span in line.get("spans", [])).strip()

            if text:
                entries.append((float(line["bbox"][1]), text))

    return entries


def join_split_marks(entries: list[tuple[float, str]]) -> list[tuple[float, str]]:
    """Rejoin allocations the scan broke across two lines.

    "(2" and "marks)" frequently land on separate lines; left alone, the audit
    reads the question as unmarked.
    """
    joined: list[tuple[float, str]] = []
    index = 0

    while index < len(entries):
        y, text = entries[index]

        if index + 1 < len(entries):
            head = SPLIT_MARKS.match(text)
            tail = MARKS_TAIL.match(entries[index + 1][1])

            if head and tail:
                joined.append((y, f"({head.group(1)} marks)"))
                index += 2
                continue

        joined.append((y, text))
        index += 1

    return joined


def read_paper(path: str) -> tuple[list[tuple[int, float, str]], dict[int, list[dict]]]:
    """Return the content lines and the tables found, both keyed by PDF page."""
    document = pymupdf.open(path)
    content: list[tuple[int, float, str]] = []
    tables: dict[int, list[dict]] = {}

    for index, page in enumerate(document):
        if index == 0:
            # Cover page: instructions numbered 1-7 that look like questions.
            continue

        found = tp.detect_tables(page.get_text("words"))

        if found:
            tables[index + 1] = found

        table_ys = [
            y
            for table in found
            for y in table["row_ys"]
        ]

        for y, text in join_split_marks(page_lines(page)):
            if not text or NOISE.search(text):
                continue
            if set(text) <= {"_", " ", ".", "…", "/", "-"}:
                continue
            # Cells are rendered from the table itself, so their text must not
            # also leak into the question prose.
            if any(abs(y - cell_y) <= tp.ROW_TOLERANCE for cell_y in table_ys):
                continue

            content.append((index + 1, y, text))

    return content, tables


def build_document(path: str) -> dict:
    numbered, tables = read_paper(path)

    # The exam instructions sit before "Section A"; the numbered questions start
    # after it.
    start = next(i for i, (_, _, line) in enumerate(numbered) if SECTION_START.match(line))
    numbered = numbered[start:]

    # Section headings carry a shared mark total ("Section B (40 marks)"). Left
    # in the stream they would be read as an allocation for the question above
    # them, so they are lifted out and re-emitted as headings.
    sections: dict[str, int] = {}
    content: list[tuple[int, float, str]] = []

    for page, y, line in numbered:
        heading = SECTION_START.match(line)

        if heading:
            sections.setdefault(heading.group(1).upper(), page)
            continue

        content.append((page, y, line))

    questions = ep.parse_questions([line for _, _, line in content], expected_total=100)

    # Where each question starts, so a table can be attached to the question it
    # belongs to rather than floating loose in the document.
    starts: dict[str, tuple[int, float]] = {}
    for page, y, line in content:
        match = re.match(r"^(\d{1,2})\.\s", line)
        if match:
            starts.setdefault(f"{match.group(1)}.", (page, y))

    blocks: list[dict] = []
    published_section_b = False

    for question in questions:
        number = int(question["label"].rstrip("."))
        page, _ = starts.get(question["label"], (2, 0.0))

        if number == 1:
            blocks.append({
                "type": "heading",
                "page": sections.get("A", page),
                "text": "Section A — short answers (60 marks)",
            })

        if number == 11 and not published_section_b:
            blocks.append({
                "type": "heading",
                "page": sections.get("B", page),
                "text": "Section B — structured questions (40 marks)",
            })
            published_section_b = True

        parts = strip_levels(question["parts"])
        marks = ep.total_marks(question["parts"]) or question.get("marks")

        block = {
            "type": "question",
            "page": page,
            "label": question["label"],
            "marks": marks,
            "text": question["stem"] or "Answer the following.",
            "parts": parts,
        }

        table = table_for(page, page_y(starts, question["label"]), tables)

        if table is not None:
            block["table"] = {"rows": tp.normalise(table["rows"])}

        blocks.append(block)

    return {
        "title": "Agriculture Paper 1 — MSCE 2017 (Mock)",
        "subtitle": "Mzuzu Diocese mock examination, M012/1, 100 marks, 2 hours.",
        "provenance": {
            "source": "msce-agriculture-paper-1-2017.pdf",
            "pages": len(pymupdf.open(path)),
            "note": "Parsed from the PDF text layer; answer lines, headers and the "
                    "question-tick table were dropped. Tables rebuilt from cell positions.",
        },
        "blocks": blocks,
    }


def page_y(starts: dict[str, tuple[int, float]], label: str) -> float:
    return starts.get(label, (0, 0.0))[1]


def table_for(page: int, y: float, tables: dict[int, list[dict]]) -> dict | None:
    """The first table on this page that begins below the question."""
    for table in tables.get(page, []):
        if table["y0"] >= y:
            return table

    return None


def strip_levels(nodes: list[dict]) -> list[dict]:
    """Drop the parser's internal ``level`` key and collapse whitespace."""
    clean = []

    for node in nodes:
        clean.append({
            "label": node["label"],
            "text": re.sub(r"\s+", " ", node.get("text") or "").strip(),
            "marks": node.get("marks"),
            "parts": strip_levels(node.get("parts") or []),
        })

    return clean


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", default=DEFAULT_PDF, help="path to the source PDF")
    parser.add_argument("--check", action="store_true", help="parse and report without writing")
    args = parser.parse_args()

    if not Path(args.pdf).is_file():
        parser.error(f"source PDF not found: {args.pdf}")

    document = build_document(args.pdf)

    total = sum(block.get("marks") or 0 for block in document["blocks"] if block["type"] == "question")
    print(f"questions {sum(1 for b in document['blocks'] if b['type'] == 'question')} marks {total}")

    for block in document["blocks"]:
        if block["type"] != "question":
            continue

        table = block.get("table")

        print(f"  {block['label']:>4} {block['marks']:>3} marks  parts {len(block['parts'])}"
              + (f"  table {len(table['rows'])}x{len(table['rows'][0])}" if table else ""))

    if args.check:
        return

    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2)

    print(f"written {OUT}")


if __name__ == "__main__":
    main()
