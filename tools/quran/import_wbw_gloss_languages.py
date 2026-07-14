#!/usr/bin/env python3
"""Import authenticated Quran.com word-by-word glosses for extra languages.

Only stores languages where Quran.com returns a real language_name match
(never copies English fallback as another language).
Also recomputes occurrence_surface / occurrence_lemma / occurrence_root.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / "app" / "assets" / "databases" / "quran.db"
CACHE = ROOT / "tools" / "quran" / "cache" / "wbw_glosses"

# language code -> expected API language_name substring
LANGS = {
    "hi": "hindi",
    "bn": "bengali",
    "id": "indonesian",
    "tr": "turkish",
    "fa": "persian",
}


def fetch_json(url: str, cache_path: Path) -> dict:
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "ISLAM307-wbw-importer/1.0", "Accept": "application/json"},
    )
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                pack = json.loads(resp.read().decode("utf-8"))
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(json.dumps(pack, ensure_ascii=False), encoding="utf-8")
            return pack
        except Exception:
            if attempt == 5:
                raise
            time.sleep(1.2 * (attempt + 1))
    return {}


def ensure_columns(conn: sqlite3.Connection) -> None:
    cols = {r[1] for r in conn.execute("PRAGMA table_info(quran_words)")}
    for lang in LANGS:
        col = f"meaning_{lang}"
        if col not in cols:
            conn.execute(f"ALTER TABLE quran_words ADD COLUMN {col} TEXT")
    for col in ("occurrence_surface", "occurrence_lemma", "occurrence_root"):
        if col not in cols:
            conn.execute(f"ALTER TABLE quran_words ADD COLUMN {col} INTEGER NOT NULL DEFAULT 0")
    conn.commit()


def import_lang(conn: sqlite3.Connection, lang: str, expect: str, sleep: float) -> int:
    col = f"meaning_{lang}"
    updated = 0
    for chapter in range(1, 115):
        url = (
            f"https://api.quran.com/api/v4/verses/by_chapter/{chapter}"
            f"?language={lang}&words=true&word_fields=text_uthmani,translation&per_page=300"
        )
        pack = fetch_json(url, CACHE / f"{lang}_{chapter:03d}.json")
        for verse in pack.get("verses", []):
            ayah = verse["verse_number"]
            for w in verse.get("words", []):
                if w.get("char_type_name") != "word":
                    continue
                tr = w.get("translation") or {}
                lang_name = (tr.get("language_name") or "").lower()
                text = (tr.get("text") or "").strip()
                # Reject English fallback disguised as another language
                if expect not in lang_name or not text:
                    text = ""
                pos = w["position"]
                cur = conn.execute(
                    f"UPDATE quran_words SET {col}=? WHERE surah=? AND ayah=? AND word_number=?",
                    (text or None, chapter, ayah, pos),
                )
                updated += cur.rowcount
        if sleep:
            time.sleep(sleep)
        print(f"  {lang} chapter {chapter}/114", flush=True)
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (f"{col}_source", f"quran.com wbw language={lang} (authenticated)"),
    )
    conn.commit()
    return updated


def recompute_occurrences(conn: sqlite3.Connection) -> None:
    print("Recomputing occurrence_surface / lemma / root…", flush=True)
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_surface = (
          SELECT COUNT(*) FROM quran_words w2 WHERE w2.text_ar = quran_words.text_ar
        )
        """
    )
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_lemma = CASE
          WHEN IFNULL(lemma,'') = '' THEN occurrence_surface
          ELSE (
            SELECT COUNT(*) FROM quran_words w2 WHERE w2.lemma = quran_words.lemma
          )
        END
        """
    )
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_root = CASE
          WHEN IFNULL(root,'') = '' THEN occurrence_lemma
          ELSE (
            SELECT COUNT(*) FROM quran_words w2 WHERE w2.root = quran_words.root
          )
        END
        """
    )
    # occurrence_count kept as root family for older UI, but UI will prefer the three fields.
    conn.execute("UPDATE quran_words SET occurrence_count = occurrence_root")
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        ("occurrence_policy", "surface=exact text_ar; lemma=same lemma; root=same root; occurrence_count=root"),
    )
    conn.commit()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--langs", default=",".join(LANGS.keys()))
    ap.add_argument("--sleep", type=float, default=0.05)
    ap.add_argument("--skip-import", action="store_true")
    ap.add_argument("--only-occurrences", action="store_true")
    args = ap.parse_args()

    conn = sqlite3.connect(args.db)
    ensure_columns(conn)

    if args.only_occurrences:
        recompute_occurrences(conn)
        conn.close()
        return 0

    if not args.skip_import:
        for lang in [x.strip() for x in args.langs.split(",") if x.strip()]:
            expect = LANGS.get(lang)
            if not expect:
                print(f"skip unknown lang {lang}")
                continue
            print(f"Importing WBW glosses: {lang}", flush=True)
            n = import_lang(conn, lang, expect, args.sleep)
            filled = conn.execute(
                f"SELECT COUNT(*) FROM quran_words WHERE IFNULL(meaning_{lang},'') != ''"
            ).fetchone()[0]
            print(f"  {lang}: rows touched={n}, filled={filled}", flush=True)

    recompute_occurrences(conn)

    # sample check مؤمنين
    row = conn.execute(
        """
        SELECT text_ar, meaning_ur, meaning_en, meaning_hi,
               occurrence_surface, occurrence_lemma, occurrence_root
        FROM quran_words
        WHERE text_ar = 'مُؤْمِنِينَ'
        LIMIT 1
        """
    ).fetchone()
    print("sample مُؤْمِنِينَ:", row)
    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
