#!/usr/bin/env python3
"""Repair Sahih Muslim Book 43 so it contains Hadith 5938–6168 only."""

from __future__ import annotations

import gzip
import json
import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GZ_PATH = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
LOCAL_DB_PATH = ROOT / "app" / "assets" / "databases" / "hadith.db"
PREVIEW_PATH = (
    ROOT / "preview" / "library" / "data" / "hadith" / "muslim.json.gz"
)

BOOK_NUMBER = 43
FIRST_HADITH = 5938
LAST_HADITH = 6168
EXPECTED_OUTLIERS = {4968, 4969, 4970, 4971, 5384, 5885, 5886}


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="islam307-muslim43-") as tmp:
        db_path = Path(tmp) / "hadith.db"
        db_path.write_bytes(gzip.decompress(GZ_PATH.read_bytes()))

        conn = sqlite3.connect(db_path)
        book_id = conn.execute(
            "SELECT id FROM books WHERE slug = 'muslim'"
        ).fetchone()[0]
        chapter = conn.execute(
            "SELECT id FROM chapters WHERE book_id = ? AND number = ?",
            (book_id, BOOK_NUMBER),
        ).fetchone()
        if chapter is None:
            raise SystemExit("Sahih Muslim Book 43 was not found")
        chapter_id = chapter[0]

        outliers = {
            row[0]
            for row in conn.execute(
                """
                SELECT hadith_number
                FROM hadiths
                WHERE book_id = ?
                  AND chapter_id = ?
                  AND hadith_number NOT BETWEEN ? AND ?
                """,
                (book_id, chapter_id, FIRST_HADITH, LAST_HADITH),
            )
        }
        if outliers not in (set(), EXPECTED_OUTLIERS):
            raise SystemExit(
                f"Unexpected Book 43 outliers: {sorted(outliers)}; "
                f"expected {sorted(EXPECTED_OUTLIERS)}"
            )

        conn.execute(
            """
            UPDATE hadiths
            SET chapter_id = NULL
            WHERE book_id = ?
              AND chapter_id = ?
              AND hadith_number NOT BETWEEN ? AND ?
            """,
            (book_id, chapter_id, FIRST_HADITH, LAST_HADITH),
        )
        conn.execute(
            """
            UPDATE chapters
            SET hadith_start = ?, hadith_end = ?
            WHERE id = ?
            """,
            (FIRST_HADITH, LAST_HADITH, chapter_id),
        )
        conn.commit()

        remaining = conn.execute(
            """
            SELECT MIN(hadith_number), MAX(hadith_number), COUNT(*)
            FROM hadiths
            WHERE book_id = ? AND chapter_id = ?
            """,
            (book_id, chapter_id),
        ).fetchone()
        conn.close()
        if remaining != (FIRST_HADITH, LAST_HADITH, 231):
            raise SystemExit(f"Book 43 validation failed: {remaining}")

        raw = db_path.read_bytes()
        GZ_PATH.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
        LOCAL_DB_PATH.write_bytes(raw)

    preview = json.loads(gzip.decompress(PREVIEW_PATH.read_bytes()))
    preview_outliers = []
    for hadith in preview["hadiths"]:
        number = int(hadith.get("n", 0))
        if number not in EXPECTED_OUTLIERS:
            continue
        if hadith.get("kitab_number") != BOOK_NUMBER:
            continue
        preview_outliers.append(number)
        hadith["kitab"] = ""
        hadith["kitab_number"] = None
        detail = hadith.get("reference_detail") or {}
        for key in ("kitab", "baab", "baab_number", "chapter_number"):
            detail[key] = ""
        for language in (detail.get("by_lang") or {}).values():
            values = language.get("values") or {}
            values["kitab"] = ""
            values["baab"] = ""
            for row in language.get("rows") or []:
                if row and row[0] in {
                    "Kitab",
                    "Baab",
                    "کتاب",
                    "باب",
                    "كتاب",
                }:
                    row[1] = ""

    remaining_preview = [
        int(hadith["n"])
        for hadith in preview["hadiths"]
        if hadith.get("kitab_number") == BOOK_NUMBER
    ]
    if min(remaining_preview) != FIRST_HADITH or max(remaining_preview) != LAST_HADITH:
        raise SystemExit(
            "Preview Book 43 validation failed: "
            f"{min(remaining_preview)}–{max(remaining_preview)}"
        )
    preview_raw = json.dumps(
        preview, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    PREVIEW_PATH.write_bytes(gzip.compress(preview_raw, compresslevel=9, mtime=0))

    print(
        f"Repaired Sahih Muslim Book 43: {FIRST_HADITH}–{LAST_HADITH}; "
        f"detached database outliers {sorted(outliers)}; "
        f"preview outliers {sorted(preview_outliers)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
