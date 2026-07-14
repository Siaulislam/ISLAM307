#!/usr/bin/env python3
"""Repair Sahih Muslim book boundaries from verified source-page mappings."""

from __future__ import annotations

import gzip
import json
import sqlite3
import tempfile
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GZ_PATH = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
LOCAL_DB_PATH = ROOT / "app" / "assets" / "databases" / "hadith.db"
PREVIEW_PATH = (
    ROOT / "preview" / "library" / "data" / "hadith" / "muslim.json.gz"
)

BOOK_43_NUMBER = 43
BOOK_43_FIRST = 5938
BOOK_43_LAST = 6168

# Verified against archived sunnah.com pages:
# - /muslim/33: Book 33, Hadith 263–266 (Sahih Muslim 715 aa–ad)
# - /muslim/36: Urdu continuation after Book 36, Hadith 257
# - /muslim/41: Book 41, Hadith 1 (Sahih Muslim 2255 a,b)
BOOK_ASSIGNMENTS = {
    4968: (33, 263),
    4969: (33, 264),
    4970: (33, 265),
    4971: (33, 266),
    5384: (36, 258),
    5885: (41, 1),
    5886: (41, 1),
}

CHAPTER_BOUNDARIES = {
    33: (4701, 4971),
    36: (5114, 5384),
    41: (5885, 5896),
    43: (5938, 6168),
}

PREVIEW_TEMPLATES = {
    33: 4967,
    36: 5383,
    41: 5887,
}


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="islam307-muslim43-") as tmp:
        db_path = Path(tmp) / "hadith.db"
        db_path.write_bytes(gzip.decompress(GZ_PATH.read_bytes()))

        conn = sqlite3.connect(db_path)
        book_id = conn.execute(
            "SELECT id FROM books WHERE slug = 'muslim'"
        ).fetchone()[0]
        chapter_ids = {
            number: chapter_id
            for number, chapter_id in conn.execute(
                """
                SELECT number, id
                FROM chapters
                WHERE book_id = ? AND number IN (33, 36, 41, 43)
                """,
                (book_id,),
            )
        }
        if set(chapter_ids) != set(CHAPTER_BOUNDARIES):
            raise SystemExit(f"Required Muslim books not found: {chapter_ids}")

        for hadith_number, (book_number, in_book_number) in BOOK_ASSIGNMENTS.items():
            exists = conn.execute(
                """
                SELECT 1 FROM hadiths
                WHERE book_id = ? AND hadith_number = ?
                """,
                (book_id, hadith_number),
            ).fetchone()
            if exists is None:
                raise SystemExit(f"Sahih Muslim Hadith {hadith_number} was not found")
            conn.execute(
                """
                UPDATE hadiths
                SET chapter_id = ?, reference_book = ?, reference_hadith = ?
                WHERE book_id = ? AND hadith_number = ?
                """,
                (
                    chapter_ids[book_number],
                    book_number,
                    in_book_number,
                    book_id,
                    hadith_number,
                ),
            )

        for book_number, (first_hadith, last_hadith) in CHAPTER_BOUNDARIES.items():
            conn.execute(
                """
                UPDATE chapters
                SET hadith_start = ?, hadith_end = ?
                WHERE id = ?
                """,
                (first_hadith, last_hadith, chapter_ids[book_number]),
            )
        conn.commit()

        book_43 = conn.execute(
            """
            SELECT MIN(hadith_number), MAX(hadith_number), COUNT(*)
            FROM hadiths
            WHERE book_id = ? AND chapter_id = ?
            """,
            (book_id, chapter_ids[BOOK_43_NUMBER]),
        ).fetchone()
        mapped = {
            row[0]: row[1]
            for row in conn.execute(
                """
                SELECT hadith_number, c.number
                FROM hadiths h
                JOIN chapters c ON c.id = h.chapter_id
                WHERE h.book_id = ?
                  AND h.hadith_number IN (4968,4969,4970,4971,5384,5885,5886)
                """,
                (book_id,),
            )
        }
        conn.close()
        if book_43 != (BOOK_43_FIRST, BOOK_43_LAST, 231):
            raise SystemExit(f"Book 43 validation failed: {book_43}")
        expected_mapping = {
            number: assignment[0]
            for number, assignment in BOOK_ASSIGNMENTS.items()
        }
        if mapped != expected_mapping:
            raise SystemExit(f"Boundary mapping validation failed: {mapped}")

        raw = db_path.read_bytes()
        GZ_PATH.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
        LOCAL_DB_PATH.write_bytes(raw)

    preview = json.loads(gzip.decompress(PREVIEW_PATH.read_bytes()))
    preview_by_number = {
        int(hadith["n"]): hadith for hadith in preview["hadiths"]
    }
    for hadith_number, (book_number, in_book_number) in BOOK_ASSIGNMENTS.items():
        hadith = preview_by_number[hadith_number]
        template = preview_by_number[PREVIEW_TEMPLATES[book_number]]
        hadith["kitab"] = template["kitab"]
        hadith["kitab_number"] = book_number
        hadith["reference_book"] = book_number
        hadith["reference_hadith"] = in_book_number
        hadith["reference"] = (
            f"Sahih Muslim · Book {book_number} · Hadith {in_book_number}"
        )
        hadith["reference_detail"] = deepcopy(template["reference_detail"])
        hadith["reference_detail"]["hadith_number"] = str(in_book_number)

    remaining_preview = [
        int(hadith["n"])
        for hadith in preview["hadiths"]
        if hadith.get("kitab_number") == BOOK_43_NUMBER
    ]
    if (
        min(remaining_preview) != BOOK_43_FIRST
        or max(remaining_preview) != BOOK_43_LAST
    ):
        raise SystemExit(
            "Preview Book 43 validation failed: "
            f"{min(remaining_preview)}–{max(remaining_preview)}"
        )
    unassigned = [
        int(hadith["n"])
        for hadith in preview["hadiths"]
        if hadith.get("kitab_number") is None
        or not str(hadith.get("kitab") or "").strip()
    ]
    if unassigned:
        raise SystemExit(f"Preview still has unassigned Muslim rows: {unassigned}")
    preview_raw = json.dumps(
        preview, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    PREVIEW_PATH.write_bytes(gzip.compress(preview_raw, compresslevel=9, mtime=0))

    print(
        f"Repaired Sahih Muslim boundaries; Book 43 is "
        f"{BOOK_43_FIRST}–{BOOK_43_LAST}; mapped "
        f"{sorted(BOOK_ASSIGNMENTS)} to Books 33, 36, and 41"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
