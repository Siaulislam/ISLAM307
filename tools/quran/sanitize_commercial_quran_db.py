#!/usr/bin/env python3
"""Keep only explicitly licensed Tanzil Arabic text in the shipped Quran DB."""

from __future__ import annotations

import sqlite3
import tempfile
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "app" / "assets" / "databases" / "quran.db"


SCHEMA = """
PRAGMA foreign_keys = ON;
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE surahs(
  id INTEGER PRIMARY KEY,
  number INTEGER NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_transliteration TEXT,
  revelation_place TEXT,
  ayah_count INTEGER NOT NULL,
  bismillah_pre INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE ayahs(
  id INTEGER PRIMARY KEY,
  global_number INTEGER NOT NULL UNIQUE,
  surah_number INTEGER NOT NULL,
  ayah_number INTEGER NOT NULL,
  text_uthmani TEXT NOT NULL,
  text_tajweed TEXT,
  translation_en TEXT,
  translation_ur TEXT,
  translation_hi TEXT,
  translation_fil TEXT,
  translation_bn TEXT,
  translation_id TEXT,
  translation_ms TEXT,
  translation_tr TEXT,
  translation_fa TEXT,
  translation_fr TEXT,
  translation_ha TEXT,
  translation_so TEXT,
  translation_ps TEXT,
  translation_sw TEXT,
  page_madani INTEGER,
  page_13_line INTEGER,
  juz INTEGER,
  hizb INTEGER,
  rub_el_hizb INTEGER,
  ruku INTEGER,
  manzil INTEGER,
  sajda_number INTEGER,
  has_sajda INTEGER NOT NULL DEFAULT 0,
  has_rub_el_hizb INTEGER NOT NULL DEFAULT 0,
  verified INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY(surah_number) REFERENCES surahs(number),
  UNIQUE(surah_number, ayah_number)
);
CREATE TABLE pages_madani(
  page_number INTEGER PRIMARY KEY, juz INTEGER, start_surah INTEGER,
  start_ayah INTEGER, end_surah INTEGER, end_ayah INTEGER
);
CREATE TABLE pages_13_line(
  page_number INTEGER PRIMARY KEY, juz INTEGER, start_surah INTEGER,
  start_ayah INTEGER, end_surah INTEGER, end_ayah INTEGER, source TEXT
);
CREATE TABLE juz(
  number INTEGER PRIMARY KEY, name_ar TEXT, start_surah INTEGER,
  start_ayah INTEGER, end_surah INTEGER, end_ayah INTEGER
);
CREATE TABLE ruku(
  number INTEGER PRIMARY KEY, surah_number INTEGER, start_ayah INTEGER,
  end_ayah INTEGER, juz INTEGER
);
CREATE TABLE sajdah(
  id INTEGER PRIMARY KEY, surah_number INTEGER, ayah_number INTEGER,
  sajda_type TEXT, UNIQUE(surah_number, ayah_number)
);
CREATE VIRTUAL TABLE ayah_fts USING fts5(
  ayah_id UNINDEXED, surah_number UNINDEXED, ayah_number UNINDEXED,
  text_uthmani, translation_en, search_blob,
  tokenize = 'unicode61 remove_diacritics 0'
);
CREATE TABLE quran_words(
  id INTEGER PRIMARY KEY, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  word_number INTEGER NOT NULL, text_ar TEXT NOT NULL, text_imlaei TEXT,
  transliteration TEXT, meaning_en TEXT, meaning_ur TEXT, root TEXT,
  lemma TEXT, pos TEXT, morphology TEXT, grammar_summary TEXT,
  syntax_summary TEXT, occurrence_count INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT '', meaning_hi TEXT, meaning_bn TEXT,
  meaning_id TEXT, meaning_tr TEXT, meaning_fa TEXT,
  occurrence_surface INTEGER NOT NULL DEFAULT 0,
  occurrence_lemma INTEGER NOT NULL DEFAULT 0,
  occurrence_root INTEGER NOT NULL DEFAULT 0,
  UNIQUE(surah, ayah, word_number)
);
CREATE TABLE quran_word_parts(
  id INTEGER PRIMARY KEY, word_id INTEGER NOT NULL, part_index INTEGER NOT NULL,
  form_bw TEXT, tag TEXT, features TEXT NOT NULL,
  FOREIGN KEY(word_id) REFERENCES quran_words(id) ON DELETE CASCADE,
  UNIQUE(word_id, part_index)
);
CREATE INDEX idx_ayahs_surah ON ayahs(surah_number, ayah_number);
CREATE INDEX idx_quran_words_ayah ON quran_words(surah, ayah);
"""


def main() -> int:
    source = sqlite3.connect(DB_PATH)
    meta = dict(source.execute("SELECT key, value FROM meta"))
    if not meta.get("source_text", "").startswith("Tanzil Project Uthmani v1.1"):
        raise SystemExit("Refusing to sanitize: Tanzil v1.1 source metadata missing")
    ayahs = source.execute(
        """
        SELECT id, global_number, surah_number, ayah_number, text_uthmani
        FROM ayahs ORDER BY global_number
        """
    ).fetchall()
    source.close()
    if len(ayahs) != 6236:
        raise SystemExit("Unexpected Quran row counts")
    counts: dict[int, int] = {}
    for row in ayahs:
        counts[row[2]] = counts.get(row[2], 0) + 1
    if set(counts) != set(range(1, 115)):
        raise SystemExit("Unexpected Surah numbering")
    surahs = [
        (
            number,
            number,
            f"سورة {number}",
            f"Surah {number}",
            None,
            None,
            counts[number],
            0,
        )
        for number in range(1, 115)
    ]
    digest = hashlib.sha256()
    for row in ayahs:
        digest.update(f"{row[2]}:{row[3]}\t{row[4]}\n".encode("utf-8"))
    text_checksum = digest.hexdigest()

    with tempfile.TemporaryDirectory(prefix="islam307-quran-license-") as tmp:
        output = Path(tmp) / "quran.db"
        conn = sqlite3.connect(output)
        conn.executescript(SCHEMA)
        conn.executemany(
            """
            INSERT INTO surahs(
              id, number, name_ar, name_en, name_transliteration,
              revelation_place, ayah_count, bismillah_pre
            ) VALUES (?,?,?,?,?,?,?,?)
            """,
            surahs,
        )
        conn.executemany(
            """
            INSERT INTO ayahs(
              id, global_number, surah_number, ayah_number, text_uthmani
            ) VALUES (?,?,?,?,?)
            """,
            ayahs,
        )
        conn.executemany(
            """
            INSERT INTO ayah_fts(
              ayah_id, surah_number, ayah_number, text_uthmani,
              translation_en, search_blob
            ) VALUES (?,?,?,?,?,?)
            """,
            [
                (row[0], row[2], row[3], row[4], "", row[4])
                for row in ayahs
            ],
        )
        conn.executemany(
            "INSERT INTO meta(key,value) VALUES (?,?)",
            [
                ("schema_version", "6_tanzil_arabic_only"),
                ("source_text", "Tanzil Project Uthmani v1.1 — tanzil.net"),
                ("license", "CC BY-ND 3.0"),
                ("attribution", "Quran text courtesy of Tanzil Project"),
                ("ayah_count", "6236"),
                ("text_sha256", text_checksum),
                ("content_policy", "Arabic only; pending datasets removed"),
            ],
        )
        conn.commit()
        conn.execute("VACUUM")
        conn.close()
        DB_PATH.write_bytes(output.read_bytes())

    print(
        f"Sanitized {DB_PATH}: 114 surahs, 6236 Tanzil Arabic ayahs, "
        "no translations, metadata packs, or word corpus."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
