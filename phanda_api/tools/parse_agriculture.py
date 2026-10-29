"""Convert the 2017 Agriculture Paper 1 PDF into a block document.

This is the thin part: read the PDF text layer, drop furniture, and hand the
lines to ``exam_parser``. All structuring rules live there, with tests.

    python parse_agriculture.py            # write the blocks file
    python parse_agriculture.py --check    # parse only, no write

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


def read_lines(path: str) -> list[tuple[int, str]]:
    """Return ``(page, line)`` pairs with furniture and answer rules removed."""
    document = pymupdf.open(path)
    collected: list[tuple[int, str]] = []

    for index, page in enumerate(document):
        if index == 0:
            # Cover page: instructions numbered 1-7 that look like questions.
            continue

        # "(2" and "marks)" land on separate lines often enough that joining
        # them first is what stops allocations going missing.
        text = re.sub(r"\((\d+)\s*\n\s*marks?\)", r"(\1 marks)", page.get_text(), flags=re.IGNORECASE)

        for raw in text.splitlines():
            line = raw.strip()
            if not line or NOISE.search(line):
                continue
            if set(line) <= {"_", " ", ".", "…", "/", "-"}:
                continue
            collected.append((index + 1, line))

    return collected


def build_document(path: str) -> dict:
    numbered = read_lines(path)

    # The exam instructions sit before "Section A"; the numbered questions start
    # after it. Everything up to the first section heading is front matter.
    start = next(i for i, (_, line) in enumerate(numbered) if SECTION_START.match(line))
    numbered = numbered[start:]

    # Section headings carry a shared mark total ("Section B (40 marks)"). Left
    # in the stream they would be read as an allocation for the question above
    # them, so they are lifted out and re-emitted as headings.
    sections: dict[str, int] = {}
    content = []
    for page, line in numbered:
        heading = SECTION_START.match(line)
        if heading:
            sections.setdefault(heading.group(1).upper(), page)
            continue
        content.append((page, line))

    lines = [line for _, line in content]
    page_of = {}
    for page, line in content:
        match = re.match(r"^(\d{1,2})\.\s", line)
        if match:
            page_of.setdefault(f"{match.group(1)}.", page)

    questions = ep.parse_questions(lines, expected_total=100)

    blocks: list[dict] = []
    published_section_b = False

    for question in questions:
        number = int(question["label"].rstrip("."))

        if number == 1:
            blocks.append({"type": "heading", "page": sections.get("A", page_of.get("1.", 2)),
                           "text": "Section A — short answers (60 marks)"})

        if number == 11 and not published_section_b:
            blocks.append({"type": "heading", "page": sections.get("B", page_of.get("11.", 7)),
                           "text": "Section B — structured questions (40 marks)"})
            published_section_b = True

        parts = strip_levels(question["parts"])
        marks = ep.total_marks(question["parts"]) or question.get("marks")

        blocks.append({
            "type": "question",
            "page": page_of.get(question["label"], 2),
            "label": question["label"],
            "marks": marks,
            "text": question["stem"] or "Answer the following.",
            "parts": parts,
        })

    return {
        "title": "Agriculture Paper 1 — MSCE 2017 (Mock)",
        "subtitle": "Mzuzu Diocese mock examination, M012/1, 100 marks, 2 hours.",
        "provenance": {
            "source": "msce-agriculture-paper-1-2017.pdf",
            "pages": len(pymupdf.open(path)),
            "note": "Parsed from the PDF text layer; answer lines, headers and the "
                    "question-tick table were dropped.",
        },
        "blocks": blocks,
    }


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
        parts = block["parts"]
        print(f"  {block['label']:>4} {block['marks']:>3} marks  parts {len(parts)}")

    if args.check:
        return

    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, indent=2)
    print(f"written {OUT}")


if __name__ == "__main__":
    main()
