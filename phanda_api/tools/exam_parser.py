"""Pure rules for turning an exam paper's text layer into structured questions.

The 2017 Agriculture paper nests three levels deep:

    7.  i.  (1) Irish potatoes  (2 marks)
            (2) Onions.         (2 marks)
        ii. (1) Which produce... (1 mark)

so a question's parts are a tree, not a list. Marks belong to the leaves only:
"i." above carries no mark of its own, and inventing one to make the total add
up is exactly the failure this module exists to prevent.

Everything here is a pure function over lines of text, so the rules can be
tested without a PDF or a database.
"""

from __future__ import annotations

import re
from typing import Iterable

#: Levels of nesting, outermost first.
LETTERED = 0
ROMAN = 1
BRACKETED = 2
NUMBERED = 3

_ROMAN_TOKENS = {"i", "ii", "iii", "iv", "v", "vi", "vii", "viii"}

# "12. a. State two" and "1a. Give two" both exist; the letter may sit against
# the number, in which case it is the first part rather than part of the number.
_QUESTION = re.compile(r"^(\d{1,2})\s*([a-h])?[\.\)]\s*(.*)$")
_LETTERED = re.compile(r"^([a-h])\.\s*(.*)$")
_LETTERED_PAREN = re.compile(r"^\(([a-h])\)\s*(.*)$", re.IGNORECASE)
#: A plain "1." inside a question body is a numbered sub-part (``d. i. 1.
#: Fractioning``), never a new question: real question lines are consumed before
#: the body is parsed.
_NUMBERED = re.compile(r"^(\d{1,2})[.)]\s*(.*)$")
_ROMAN_PAREN = re.compile(r"^\(([ivx]{1,4})\)\s*(.*)$", re.IGNORECASE)
_ROMAN_DOT = re.compile(r"^([ivx]{1,4})[.)]\s*(.*)$", re.IGNORECASE)
_BRACKETED = re.compile(r"^\((\d{1,2})\)\s*(.*)$")
_MARKS = re.compile(r"\((\d+)\s*marks?\)", re.IGNORECASE)


def split_marks(line: str) -> tuple[str, int | None]:
    """Peel a trailing ``(2 marks)`` off a line.

    The paper sometimes puts the allocation alone on its own line, so the text
    can legitimately come back empty.
    """
    found = _MARKS.findall(line)

    if not found:
        return line.strip(), None

    return _MARKS.sub("", line).strip(), int(found[-1])


def classify(text: str) -> tuple[int, str, str] | None:
    """Identify a part label and the text that follows it.

    Returns ``(level, label, rest)`` or ``None`` for ordinary prose.

    A roman label only counts when the token is a real numeral *and* carries its
    punctuation, which is what stops "Identify", "very" and "In the table" from
    becoming parts (i), (v) and (i).
    """
    stripped = text.strip()

    match = _BRACKETED.match(stripped)
    if match:
        return BRACKETED, f"({match.group(1)})", _clean(match.group(2))

    match = _ROMAN_PAREN.match(stripped)
    if match and match.group(1).lower() in _ROMAN_TOKENS:
        return ROMAN, f"({match.group(1).lower()})", _clean(match.group(2))

    match = _ROMAN_DOT.match(stripped)
    if match and match.group(1).lower() in _ROMAN_TOKENS:
        return ROMAN, f"{match.group(1).lower()}.", _clean(match.group(2))

    # "(a)" is a lettered part when it is not a roman numeral; (i), (v) and
    # (x) were already claimed by the roman patterns above.
    match = _LETTERED_PAREN.match(stripped)
    if match:
        return LETTERED, f"({match.group(1)})", _clean(match.group(2))

    match = _LETTERED.match(stripped)
    if match:
        return LETTERED, f"{match.group(1)}.", _clean(match.group(2))

    match = _NUMBERED.match(stripped)
    if match:
        return NUMBERED, f"{match.group(1)}.", _clean(match.group(2))

    return None


def _next_number(node: dict | None) -> int:
    """The numbered sub-part this node is waiting for."""
    if node is None:
        return 1

    # Inside a numbered sub-item, the next number is its sibling.
    if node["level"] == NUMBERED:
        return int(node["label"].rstrip(".")) + 1

    return sum(1 for child in node["parts"] if child["level"] == NUMBERED) + 1


def _clean(rest: str) -> str:
    """Drop punctuation a label leaves behind, as in ``(i). Define the term``."""
    return rest.lstrip(" .):;-\u2013\u2014").strip()


def _new_part(level: int, label: str, text: str, marks: int | None) -> dict:
    return {"level": level, "label": label, "text": text, "marks": marks, "parts": []}


def parse_parts(lines: Iterable[str], max_depth: int = 3) -> list[dict]:
    """Build the part tree for one question body.

    A line may carry more than one label, because the paper writes the first
    part on the question line and the first sub-part on the part line:

        ``b. (i) Give any one reason why it is important...``
    """
    roots: list[dict] = []
    stack: list[dict] = []
    current: dict | None = None

    for raw in lines:
        line = raw.strip()
        if not line:
            continue

        text, marks = split_marks(line)

        # "______(2 marks)" is an answer space with its allocation, not prose.
        text = _RULED.sub(" ", text).strip()

        chain: list[tuple[int, str, str]] = []
        probe = text
        while probe and len(chain) < max_depth:
            found = classify(probe)
            if found is None:
                break
            chain.append(found)
            probe = found[2]

        # A numbered line is only a sub-part when it continues the sequence and
        # sits under an open part. "3." arriving where "1." was due is the
        # paper's own numbering error, and treating it as a part would shadow
        # its parent's marks.
        if chain and chain[0][0] == NUMBERED:
            wanted = _next_number(current)
            if current is None or int(chain[0][1].rstrip(".")) != wanted:
                chain = []

        if chain:
            for index, (level, label, rest) in enumerate(chain):
                # Only the innermost label owns the text: "b. (i) Give one
                # reason" must not leave the reason attached to (b) as well.
                text_here = rest if index == len(chain) - 1 else ""
                node = _new_part(level, label, text_here, None)
                while stack and stack[-1]["level"] >= level:
                    stack.pop()
                if stack:
                    stack[-1]["parts"].append(node)
                else:
                    roots.append(node)
                stack.append(node)
                current = node

            # Marks written on the label line belong to the innermost label.
            if marks is not None and current is not None:
                current["marks"] = marks

            # Text after the last label, e.g. "i. Scarification".
            if probe and current is not None and not current["text"]:
                current["text"] = probe

            continue

        if current is None:
            continue

        if marks is not None:
            current["marks"] = marks

        if text:
            current["text"] = f"{current['text']} {text}".strip()

    return roots


def leaf_marks(node: dict) -> int:
    """Marks carried by a node, counting only answer-bearing leaves."""
    children = node.get("parts") or []

    if children:
        return sum(leaf_marks(child) for child in children)

    return node.get("marks") or 0


def total_marks(nodes: Iterable[dict]) -> int:
    return sum(leaf_marks(node) for node in nodes)


def question_marks(question: dict) -> int:
    """A question's worth: its leaves if it has parts, else its own allocation."""
    parts = question.get("parts") or []

    if parts:
        return total_marks(parts)

    return question.get("marks") or 0


def _heads_question(rest: str, ahead: list[str], big: int = 5) -> bool:
    """Does this numbered line start a question, or is it a numbered sub-item?

    ``2. Creaking`` under part (i) of question 1 is indistinguishable from
    question 2 by its number alone, so the decision is made by what a question
    looks like: it opens with a lettered part, or it is followed by one, or it
    carries a substantial allocation. A numbered sub-item has none of those.
    """
    # A numbered sub-item is a short noun phrase ("2. Creaking"); a question is
    # a sentence. Length and a question mark separate them when the number alone
    # cannot, and the ascending gate catches a wrong call because a sub-item
    # never carries the next question's number by accident.
    stripped = rest.strip()
    if len(stripped) >= 40 or "?" in stripped:
        return True

    found = classify(rest)
    if found and found[0] == LETTERED:
        return True

    for line in ahead:
        text, marks = split_marks(line)
        if marks is not None and marks >= big:
            return True
        found = classify(text)
        if found and found[0] == LETTERED:
            return True

    return False


def parse_questions(
    lines: Iterable[str],
    first_number: int = 1,
    expected_total: int | None = None,
) -> list[dict]:
    """Group lines into numbered questions.

    A question number only counts when it follows the previous one by exactly
    one, so a stray year or a numbered instruction cannot start a question.
    """
    questions: list[dict] = []
    body: list[str] | None = None
    expected = first_number

    def flush() -> None:
        if body is None or not questions:
            return

        question = questions[-1]
        stem = question["stem"]

        # "2. a. Mention any two beef breeds" — the first part shares the
        # question line, so the stem has to be parsed with the body or part (a)
        # disappears.
        lines_in = ([stem] if classify(stem) else []) + body
        parts = parse_parts(lines_in)

        if parts:
            question["parts"] = parts
            if classify(stem):
                question["stem"] = ""
            return

        # A question with no labelled parts is prose plus one allocation, e.g.
        # Section B's "11. ... (10 marks)".
        text, marks = split_marks(" ".join([stem] + body))
        question["stem"] = re.sub(r"\s+", " ", text).strip()
        question["marks"] = marks

    for position, raw in enumerate(lines):
        line = raw.strip()
        if not line:
            continue

        match = _QUESTION.match(line)
        number = int(match.group(1)) if match else None
        # The first question defines where the paper starts, so it is taken on
        # its number alone; after that a heading has to look like one.
        heads_question = number == expected and (
            not questions
            or _heads_question(
                match.group(3) if match else "", lines[position + 1 : position + 4]
            )
        )

        if match and heads_question:
            flush()
            stem = match.group(3).strip()
            inline = match.group(2)

            # "1a. Give two examples" carries its first part on the question
            # line; keep the letter so the part is not lost.
            if inline:
                stem = f"{inline}. {stem}".strip()

            questions.append({"label": f"{number}.", "stem": stem, "parts": [], "marks": None})
            body = []
            expected += 1
            continue

        if body is not None:
            body.append(line)

    flush()

    if expected_total is not None:
        seen = sum(question_marks(q) for q in questions)
        if seen != expected_total:
            raise ValueError(f"parsed {seen} marks, paper states {expected_total}")

    return questions

#: Page furniture that belongs to the paper, not to any question.
FURNITURE = re.compile(
    r"(Name_+|Page \d+ of \d+|Turn over|Continued|\u00a9|"
    r"Answer all|maximum number of marks|spaces provided|Write your name|"
    r"In the table provided|Hand in your paper)",
    re.IGNORECASE,
)

_RULED = re.compile(r"_{3,}")
_SEPARATOR = re.compile(r"^[_.\u2026/\-\s]+$")

#: A section heading states the shared total for its questions ("Section B
#: (40 marks)"). Kept in the stream it is read as the allocation of whichever
#: question precedes it.
_SECTION = re.compile(r"^SECTION\s+[A-D]\b", re.IGNORECASE)
_SPLIT_HEAD = re.compile(r"^\((\d+)$")
_SPLIT_TAIL = re.compile(r"^marks?\)$", re.IGNORECASE)


def is_furniture(line: str) -> bool:
    """True for headers, footers, ruled answer space and section headings."""
    return (
        not line.strip()
        or bool(FURNITURE.search(line))
        or bool(_SEPARATOR.match(line))
        or bool(_SECTION.match(line))
    )


def reading_lines(text: str) -> list[str]:
    """Turn one or more pages of text into the lines a paper is read from.

    Keeps order, drops furniture, and rejoins an allocation the scan split over
    two lines ("(2" then "marks)"), which otherwise reads as an unmarked
    question.
    """
    raw = [line.strip() for line in text.splitlines() if line.strip()]
    lines: list[str] = []
    index = 0

    while index < len(raw):
        line = raw[index]

        if index + 1 < len(raw):
            head = _SPLIT_HEAD.match(line)
            tail = _SPLIT_TAIL.match(raw[index + 1])

            if head and tail:
                count = head.group(1)
                lines.append(f"({count} mark{'s' if count != '1' else ''})")
                index += 2
                continue

        if not is_furniture(line):
            lines.append(line)

        index += 1

    return lines
