#!/usr/bin/env python3
"""Build empty narrators.db scaffold for ISLAM 307.

POLICY (STRICT):
  - Never invent narrator names, biographies, teachers, students, dates, or reliability.
  - Never use AI, Wikipedia, blogs, forums, or unapproved websites.
  - Only import from approved classical Sunni references when a licensed dataset is available.
  - This script ships the schema + approved source catalog only (zero biography rows).

Usage:
  python3 tools/narrators/build_narrators_db.py
  # writes app/assets/databases/narrators.db.gz
"""

from __future__ import annotations

import gzip
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = Path(__file__).with_name("schema.sql")
OUT_DB = ROOT / "app" / "assets" / "databases" / "narrators.db"
OUT_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"

# Approved classical Sunni references ONLY (license/permission still required to import text).
APPROVED_SOURCES = [
    (1, "tahdhib-al-kamal", "تهذيب الكمال", "Tahdhib al-Kamal", "Imam al-Mizzi", "الإمام المزي", 1),
    (2, "tahdhib-al-tahdhib", "تهذيب التهذيب", "Tahdhib al-Tahdhib", "Imam Ibn Hajar al-Asqalani", "ابن حجر العسقلاني", 2),
    (3, "taqrib-al-tahdhib", "تقريب التهذيب", "Taqrib al-Tahdhib", "Imam Ibn Hajar al-Asqalani", "ابن حجر العسقلاني", 3),
    (4, "siyar-alam-al-nubala", "سير أعلام النبلاء", "Siyar A'lam al-Nubala", "Imam al-Dhahabi", "الإمام الذهبي", 4),
    (5, "al-isabah", "الإصابة في تمييز الصحابة", "Al-Isabah fi Tamyiz al-Sahabah", "Imam Ibn Hajar al-Asqalani", "ابن حجر العسقلاني", 5),
    (6, "mizan-al-itidal", "ميزان الاعتدال", "Mizan al-I'tidal", "Imam al-Dhahabi", "الإمام الذهبي", 6),
    (7, "lisan-al-mizan", "لسان الميزان", "Lisan al-Mizan", "Imam Ibn Hajar al-Asqalani", "ابن حجر العسقلاني", 7),
    (8, "tabaqat-ibn-sad", "الطبقات الكبرى", "Tabaqat Ibn Sa'd", "Ibn Sa'd", "ابن سعد", 8),
    (9, "tarikh-al-kabir", "التاريخ الكبير", "Tarikh al-Kabir", "Imam al-Bukhari", "الإمام البخاري", 9),
    (10, "al-jarh-wa-al-tadil", "الجرح والتعديل", "Al-Jarh wa al-Ta'dil", "Ibn Abi Hatim", "ابن أبي حاتم", 10),
]


def main() -> int:
    OUT_DB.parent.mkdir(parents=True, exist_ok=True)
    if OUT_DB.exists():
        OUT_DB.unlink()
    if OUT_GZ.exists():
        OUT_GZ.unlink()

    conn = sqlite3.connect(OUT_DB)
    try:
        conn.executescript(SCHEMA.read_text(encoding="utf-8"))
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("schema_version", "1_rijal"),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            (
                "policy",
                "Never invent narrator data with AI. Approved classical Sunni sources only. "
                "If a narrator row is not in this database yet, the app shows: "
                "This narrator profile has not been imported into the local database yet.",
            ),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("biography_rows", "0"),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("hadith_mappings", "0"),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            (
                "import_note",
                "Sources cataloged. Biography and hadith→narrator rows require a licensed import. "
                "Do not scrape Wikipedia, blogs, forums, or unapproved sites.",
            ),
        )

        for row in APPROVED_SOURCES:
            conn.execute(
                """
                INSERT INTO sources(
                  id, slug, name_ar, name_en, author_en, author_ar, sort_order,
                  license_status, attribution, notes, approved
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'permission_required', ?, ?, 1)
                """,
                (
                    row[0],
                    row[1],
                    row[2],
                    row[3],
                    row[4],
                    row[5],
                    row[6],
                    f"{row[3]} — {row[4]}. Use only with license/permission for intended distribution.",
                    "Approved classical Sunni reference. Text not bundled until a licensed offline pack is imported.",
                ),
            )
        conn.commit()

        # Sanity: zero biography content
        n = conn.execute("SELECT COUNT(*) FROM narrators").fetchone()[0]
        m = conn.execute("SELECT COUNT(*) FROM hadith_relations").fetchone()[0]
        s = conn.execute("SELECT COUNT(*) FROM sources").fetchone()[0]
        if n != 0 or m != 0:
            raise SystemExit(f"Refusing to ship non-empty narrators/mappings (n={n}, m={m})")
        if s != len(APPROVED_SOURCES):
            raise SystemExit(f"Expected {len(APPROVED_SOURCES)} sources, got {s}")
    finally:
        conn.close()

    raw = OUT_DB.read_bytes()
    with gzip.open(OUT_GZ, "wb", compresslevel=9) as gz:
        gz.write(raw)
    OUT_DB.unlink()  # ship gzip only (matches hadith/tafsir)
    print(f"Wrote {OUT_GZ} ({OUT_GZ.stat().st_size} bytes) — schema + {len(APPROVED_SOURCES)} approved sources, 0 biographies.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
