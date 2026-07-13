#!/usr/bin/env python3
"""Run Gold Standard regression — required before merging Isnad Engine changes."""

from __future__ import annotations

import gzip
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "hadith"))

from isnad_engine.engine import parse_hadith_isnad  # noqa: E402
from isnad_engine.normalize import match_key  # noqa: E402

GOLD_DIR = ROOT / "hadith" / "isnad_engine" / "gold"
DB_GZ = Path(__file__).resolve().parents[3] / "app/assets/databases/hadith.db.gz"

BOOKS = (
    "bukhari",
    "muslim",
    "abudawud",
    "tirmidhi",
    "nasai",
    "ibnmajah",
)

MIN_PER_BOOK = 100


def _names_equal(got: list[str], expected: list[str]) -> bool:
    if len(got) != len(expected):
        return False
    return all(match_key(a) == match_key(b) for a, b in zip(got, expected))


def _load_db() -> sqlite3.Connection:
    raw = gzip.open(DB_GZ, "rb").read()
    tf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tf.write(raw)
    tf.close()
    return sqlite3.connect(tf.name)


def main() -> int:
    if not GOLD_DIR.is_dir():
        print(f"FAIL: gold dir missing: {GOLD_DIR}", file=sys.stderr)
        return 1
    con = _load_db()
    failures: list[str] = []
    totals = 0
    for book in BOOKS:
        path = GOLD_DIR / f"{book}.jsonl"
        if not path.exists():
            failures.append(f"{book}: missing {path}")
            continue
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
        if len(rows) < MIN_PER_BOOK:
            failures.append(f"{book}: only {len(rows)} gold rows (need >={MIN_PER_BOOK})")
        bid = con.execute("SELECT id FROM books WHERE slug=?", (book,)).fetchone()
        if not bid:
            failures.append(f"{book}: not in hadith.db")
            continue
        for row in rows:
            totals += 1
            num = int(row["hadith_number"])
            expected = row["expected_names"]
            db_row = con.execute(
                "SELECT text_ar FROM hadiths WHERE book_id=? AND hadith_number=? ORDER BY id LIMIT 1",
                (bid[0], num),
            ).fetchone()
            if not db_row or not db_row[0]:
                failures.append(f"{book}#{num}: missing text_ar in DB")
                continue
            got = parse_hadith_isnad(
                db_row[0], book_slug=book, hadith_number=num
            ).primary_names
            if not _names_equal(got, expected):
                failures.append(
                    f"{book}#{num}: expected {expected!r} got {got!r}"
                )
            # Also enforce isnad cut still matches stored sanad when provided
            stored_isnad = row.get("isnad_ar") or ""
            if stored_isnad and any(
                leak in stored_isnad
                for leak in ("قال رسول الله", "قال النبي صلى")
            ):
                failures.append(f"{book}#{num}: stored isnad_ar contains matn opener")

    if failures:
        print(f"Gold Standard FAILED ({len(failures)} issues, scanned {totals}):", file=sys.stderr)
        for line in failures[:40]:
            print(f"  - {line}", file=sys.stderr)
        if len(failures) > 40:
            print(f"  ... and {len(failures) - 40} more", file=sys.stderr)
        return 1

    print(f"Gold Standard PASSED: {totals} hadith across {len(BOOKS)} books.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
