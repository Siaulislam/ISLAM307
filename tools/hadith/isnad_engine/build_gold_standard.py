#!/usr/bin/env python3
"""Build Gold Standard isnad fixtures from authenticated hadith.db.gz.

Selection rules (verified against Arabic Isnad structure):
- Clear sanad cut before Prophet speech / Matn openers
- >= 2 extracted narrators
- No story-character / matn-verb leakage in names
- No relative tokens stored as display names
- Prefer evenly spaced hadith numbers across each book

Output JSONL is the permanent regression oracle: parser updates must match it.
Musnad Ahmad is reserved (no corpus rows in hadith.db yet).
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # repo root
HADITH_TOOLS = ROOT / "tools" / "hadith"
sys.path.insert(0, str(HADITH_TOOLS))

from hadith_meta import _cut_isnad_ar, _fold_ar  # noqa: E402
from isnad_engine.engine import parse_hadith_isnad  # noqa: E402
from isnad_engine.matn_guards import (  # noqa: E402
    MATN_OPEN_VERBS,
    is_story_character,
    looks_like_matn_verb_name,
)
from isnad_engine.normalize import is_relative_token  # noqa: E402

BOOKS = (
    "bukhari",
    "muslim",
    "abudawud",
    "tirmidhi",
    "nasai",
    "ibnmajah",
)

GOLD_DIR = Path(__file__).resolve().parent / "gold"

_STORY_RE = re.compile(
    r"هرقل|كسري|كسرى|النجاشي|المقوقس|ابو\s*جهل|ابو\s*لهب|"
    r"اميه\s*بن\s*خلف|عتبه\s*بن\s*ربيعه|شيطان|ابليس",
    re.UNICODE,
)


def _open_db(gz_path: Path) -> sqlite3.Connection:
    raw = gzip.open(gz_path, "rb").read()
    tf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tf.write(raw)
    tf.close()
    return sqlite3.connect(tf.name)


def _text_hash(text: str) -> str:
    return hashlib.sha256((text or "").encode("utf-8")).hexdigest()[:16]


def _passes_invariants(ar: str, book: str, number: int) -> tuple[bool, list[str], str, str]:
    cut = _cut_isnad_ar(ar or "")
    if len(cut) < 20:
        return False, [], cut, "cut_too_short"
    folded_cut = _fold_ar(cut)
    # Cut must not still contain clear matn openers with Prophet
    if re.search(
        r"قال\s+رسول\s*الله|قال\s+النبي|"
        r"(?:قام|خرج|دخل|كان|بينما|بعث|اتي|جاء|خطب|صلي|نهي|امر)\s+"
        r"(?:فينا\s+)?(?:رسول\s*الله|النبي)",
        folded_cut,
    ):
        return False, [], cut, "matn_in_cut"
    if _STORY_RE.search(folded_cut) and re.search(r"ارسل|دعا|في\s+ركب", folded_cut):
        return False, [], cut, "story_in_cut"

    result = parse_hadith_isnad(ar, book_slug=book, hadith_number=number)
    names = [n for n in result.primary_names if n and "رسول الله" not in n]
    if len(names) < 2:
        return False, result.primary_names, cut, "too_few_names"
    if any(is_relative_token(n) for n in names):
        return False, result.primary_names, cut, "relative_as_name"
    if any(looks_like_matn_verb_name(n) for n in names):
        return False, result.primary_names, cut, "matn_verb_name"
    if any(is_story_character(n) for n in names):
        return False, result.primary_names, cut, "story_character"
    # Reject single-token matn verbs explicitly
    for n in names:
        f = _fold_ar(n)
        if f in MATN_OPEN_VERBS or f in {"رجل", "امراة", "قوم", "ناس", "الله"}:
            return False, result.primary_names, cut, "grammar_token"
    return True, result.primary_names, cut, "ok"


def select_gold(con: sqlite3.Connection, book: str, target: int = 100) -> list[dict]:
    bid = con.execute("SELECT id FROM books WHERE slug=?", (book,)).fetchone()
    if not bid:
        raise SystemExit(f"book not found: {book}")
    rows = con.execute(
        "SELECT hadith_number, text_ar FROM hadiths WHERE book_id=? AND text_ar IS NOT NULL "
        "AND length(text_ar) > 40 ORDER BY hadith_number",
        (bid[0],),
    ).fetchall()
    if not rows:
        raise SystemExit(f"no rows for {book}")

    # Force-include known regression fixtures when they pass invariants.
    force_nums = {
        "bukhari": {1, 2, 6, 7},
        "abudawud": {4240},
        "muslim": {1},
    }.get(book, set())

    # Evenly spaced candidates across the book, then fill gaps sequentially.
    step = max(1, len(rows) // (target * 3))
    candidates = list(range(0, len(rows), step))
    for prefer in sorted(force_nums | {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}):
        for i, (num, _) in enumerate(rows):
            if num == prefer and i not in candidates:
                candidates.insert(0, i)

    selected: list[dict] = []
    seen_num: set[int] = set()

    def try_add(num: int, ar: str) -> bool:
        if num in seen_num or len(selected) >= target:
            return False
        ok, names, cut, _reason = _passes_invariants(ar, book, num)
        if not ok:
            return False
        seen_num.add(num)
        selected.append(
            {
                "book_slug": book,
                "hadith_number": int(num),
                "text_sha256_16": _text_hash(ar),
                "isnad_ar": cut,
                "expected_names": names,
                "verification": {
                    "method": "arabic_isnad_structure",
                    "invariants": [
                        "sanad_only_cut",
                        "no_story_characters",
                        "no_matn_verb_names",
                        "no_relative_display_names",
                        "min_two_narrators",
                    ],
                    "status": "verified",
                    "fixture": num in force_nums,
                },
            }
        )
        return True

    # Prefer force fixtures first
    by_num = {num: ar for num, ar in rows}
    for num in sorted(force_nums):
        if num in by_num:
            try_add(num, by_num[num])

    for i in candidates:
        if len(selected) >= target:
            break
        num, ar = rows[i]
        try_add(num, ar)

    # Sequential fill if evenly-spaced pass was sparse
    if len(selected) < target:
        for num, ar in rows:
            if len(selected) >= target:
                break
            try_add(num, ar)

    selected.sort(key=lambda r: r["hadith_number"])
    return selected[:target]


def write_manifest(gold_dir: Path, counts: dict[str, int]) -> None:
    manifest = {
        "title": "Arabic Isnad Engine Gold Standard",
        "rule": "No parser update may merge unless all Gold Standard tests pass.",
        "books": counts,
        "reserved": {
            "musnad_ahmad": "Parser supports book_slug=ahmad; corpus not in hadith.db yet.",
            "muwatta": "Covered by regression scan when malik/muwatta rows exist.",
        },
        "edge_cases": "See tools/hadith/tests/test_isnad_edge_cases.py (patterns 1–20).",
    }
    (gold_dir / "MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (gold_dir / "README.md").write_text(
        "# Isnad Engine Gold Standard\n\n"
        "Permanent regression oracle for Arabic sanad parsing.\n\n"
        "- **100** verified entries per: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasai, Ibn Majah\n"
        "- Each row stores `isnad_ar` (sanad-only cut) and `expected_names` checked against Arabic Isnad\n"
        "- Invariants: zero Matn leakage, no story characters, relatives not stored as names\n"
        "- Gate: `python3 tools/hadith/tests/run_isnad_gold.py` (also via `run_all_isnad_gates.sh`)\n\n"
        "Do not invent narrators. Re-build only after intentional, reviewed parser changes:\n"
        "`python3 tools/hadith/isnad_engine/build_gold_standard.py`\n",
        encoding="utf-8",
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-book", type=int, default=100)
    ap.add_argument(
        "--db",
        type=Path,
        default=ROOT / "app/assets/databases/hadith.db.gz",
    )
    args = ap.parse_args()
    db = args.db
    if not db.exists():
        print(f"DB not found: {db}", file=sys.stderr)
        return 1
    GOLD_DIR.mkdir(parents=True, exist_ok=True)
    con = _open_db(db)
    counts: dict[str, int] = {}
    for book in BOOKS:
        rows = select_gold(con, book, target=args.per_book)
        out = GOLD_DIR / f"{book}.jsonl"
        with out.open("w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        counts[book] = len(rows)
        print(f"{book}: wrote {len(rows)} → {out}")
        if len(rows) < args.per_book:
            print(f"  WARNING: wanted {args.per_book}, got {len(rows)}", file=sys.stderr)
    write_manifest(GOLD_DIR, counts)
    total = sum(counts.values())
    print(f"Total gold rows: {total}")
    return 0 if all(c >= args.per_book for c in counts.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
