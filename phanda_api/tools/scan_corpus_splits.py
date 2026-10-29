"""Report how the corpus divides into papers, schemes and unknowns.

    python scan_corpus_splits.py --root G:\\FlutterApps\\school-papers

Writes corpus-splits.csv: one row per segment, so a 40-page file containing
Paper I, Paper II and a marking scheme becomes three rows instead of one
unusable lump.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import Counter
from pathlib import Path

import pymupdf

import paper_splitter as ps

CSV_OUT = Path("corpus-splits.csv")


def page_texts(path: Path) -> list[str]:
    """Per-page text, so segments can be attributed to pages."""
    texts: list[str] = []

    try:
        document = pymupdf.open(path)
    except Exception:
        return texts

    if document.needs_pass:
        return texts

    for page in document:
        try:
            texts.append(page.get_text())
        except Exception:
            texts.append("")

    return texts


def scan(root: Path) -> list[dict]:
    rows: list[dict] = []

    for path in sorted(root.rglob("*")):
        if path.suffix.lower() != ".pdf":
            continue

        pages = page_texts(path)

        if not pages:
            continue

        segments = ps.split_papers(pages)

        for segment in segments:
            span = pages[segment["start"] - 1 : segment["end"]]
            cover = span[0] if span else ""
            total = None

            for page in span[:2]:
                total = ps.stated_marks(page)

                if total:
                    break

            rows.append(
                {
                    "subject": path.relative_to(root).parts[0],
                    "file": str(path.relative_to(root)),
                    "kind": segment["kind"],
                    "paper": segment["paper"] or "",
                    "start": segment["start"],
                    "end": segment["end"],
                    "pages": segment["pages"],
                    "stated_marks": total or "",
                    "is_scanned": "no" if len(cover.strip()) > 40 else "yes",
                }
            )

    return rows


def report(rows: list[dict]) -> None:
    per_file = Counter((r["file"], r["subject"]) for r in rows)
    splits = Counter(count for count in per_file.values())

    print(f"segments: {len(rows)} across {len(per_file)} files")

    for parts, files in sorted(splits.items()):
        print(f"  {parts} segment(s): {files} file(s)")

    kinds = Counter(r["kind"] for r in rows)
    print("by kind:", dict(kinds))

    papers = [r for r in rows if r["kind"] == "paper"]
    stated = [r for r in papers if r["stated_marks"]]
    print(f"paper segments: {len(papers)}, of which {len(stated)} state a total")

    totals = Counter(r["stated_marks"] for r in stated)
    print("stated totals:", totals.most_common(6))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()

    rows = scan(args.root)

    with CSV_OUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"written {CSV_OUT} ({len(rows)} rows)")
    report(rows)


if __name__ == "__main__":
    main()
