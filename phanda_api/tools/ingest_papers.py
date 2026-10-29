"""Try every queued paper segment and record whether it reconciles.

    python ingest_papers.py --root G:\\FlutterApps\\school-papers

Reads corpus-splits.csv, parses each single paper segment on its own, and writes
corpus-parse-results.csv. A paper that reconciles to its stated total is ready
for review; one that does not is a content problem to look at, not a parser bug
to paper over.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
from collections import Counter
from pathlib import Path

import pymupdf

import exam_parser as ep

SPLITS = Path("corpus-splits.csv")
RESULTS = Path("corpus-parse-results.csv")

#: A real single paper. Longer segments are books that mention a paper.
MAX_PAGES = 20

COVER_HINTS = ("INSTRUCTION", "TIME ALLOWED", "ANSWER ALL", "CERTIFICATE")


def segment_pages(path: Path, start: int, end: int) -> list[str]:
    try:
        document = pymupdf.open(path)
    except Exception:
        return []

    if document.needs_pass:
        return []

    texts: list[str] = []

    for index in range(start - 1, min(end, len(document))):
        try:
            texts.append(document[index].get_text())
        except Exception:
            texts.append("")

    return texts


def drop_cover(pages: list[str]) -> list[str]:
    """The cover numbers its instructions 1..7, which read as questions."""
    if pages and any(hint in pages[0].upper() for hint in COVER_HINTS):
        return pages[1:]

    return pages


def file_hash(path: Path) -> str:
    """Content fingerprint: the corpus keeps the same paper in several subject
    folders, and counting every copy as a parsed paper flatters the result."""
    digest = hashlib.sha1()

    with path.open("rb") as handle:
        while chunk := handle.read(1 << 20):
            digest.update(chunk)

    return digest.hexdigest()[:12]


def parse_segment(root: Path, row: dict) -> dict:
    path = root / row["file"]
    pages = drop_cover(segment_pages(path, int(row["start"]), int(row["end"])))
    lines = ep.reading_lines("\n".join(pages))

    stated = int(row["stated_marks"]) if row["stated_marks"] else None
    result = {
        "subject": row["subject"],
        "file": row["file"],
        "paper": row["paper"],
        "pages": row["pages"],
        "stated_marks": stated or "",
        "lines": len(lines),
        "sha1": file_hash(path),
    }

    try:
        # No expected_total here: a mismatch is a finding to record, not an
        # exception, and the question count still tells us how the paper read.
        questions = ep.parse_questions(lines)
    except Exception as error:  # noqa: BLE001 - recorded, not swallowed
        result.update(
            {"status": "error", "parsed_marks": "", "questions": "", "notes": str(error)[:120]}
        )

        return result

    total = sum(ep.question_marks(q) for q in questions)
    unweighted = sum(1 for q in questions if not (q.get("parts") or q.get("marks")))

    # Not every paper is a numbered question paper. English and Chichewa papers
    # are task sheets ("NOTE MAKING", "COMPOSITION") and have no questions to
    # find; grouping them separately stops them looking like parser failures.
    if len(questions) >= 5:
        genre = "numbered"
    elif not questions:
        genre = "tasks"
    else:
        genre = "partial"

    result.update(
        {
            "status": "ok" if total == (stated or total) else "mismatch",
            "parsed_marks": total,
            "questions": len(questions),
            "genre": genre,
            "notes": f"{unweighted} unweighted" if unweighted else "",
        }
    )

    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()

    queue = [
        row
        for row in csv.DictReader(SPLITS.open(encoding="utf-8"))
        if row["kind"] == "paper"
        and row["stated_marks"]
        and int(row["pages"]) <= MAX_PAGES
    ]

    results = [parse_segment(args.root, row) for row in queue]

    with RESULTS.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(results[0].keys()))
        writer.writeheader()
        writer.writerows(results)

    print(f"written {RESULTS} ({len(results)} papers)")
    print("by status:", dict(Counter(r["status"] for r in results)))
    print("by genre:", dict(Counter(r.get("genre", "?") for r in results)))

    ok = [r for r in results if r["status"] == "ok"]
    distinct = len({r.get("sha1") for r in ok})
    print(f"reconciled exactly: {len(ok)} rows, {distinct} distinct files")

    for result in results:
        if result["status"] != "ok":
            print(
                f'  {result["status"]:<9} {result["parsed_marks"]:>4}/{result["stated_marks"]:<4} '
                f'{result["file"][:62]}'
            )


if __name__ == "__main__":
    main()
