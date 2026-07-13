#!/usr/bin/env python3
"""Download authenticated Quran ayah translations into quran.db (offline).

Sources: Quran.com API v4 translation resources only.
Never invents or machine-translates Quran text.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / "app" / "assets" / "databases" / "quran.db"

# lang_code -> (quran.com translation_id, display name, author/source note)
TRANSLATIONS: dict[str, tuple[int, str, str]] = {
    "en": (20, "Saheeh International", "quran.com id=20 Saheeh International"),
    "hi": (122, "Hindi — Maulana Azizul Haque al-Umari", "quran.com id=122 Maulana Azizul Haque al-Umari"),
    "fil": (211, "Filipino (Tagalog) — Dar Al-Salam Center", "quran.com id=211 Dar Al-Salam Center"),
    "bn": (161, "Bengali — Taisirul Quran", "quran.com id=161 Taisirul Quran / Tawheed Publication"),
    "id": (33, "Indonesian — Ministry of Religious Affairs", "quran.com id=33 Indonesian Islamic Affairs Ministry"),
    "ms": (39, "Malay — Abdullah Muhammad Basmeih", "quran.com id=39 Abdullah Muhammad Basmeih"),
    "tr": (77, "Turkish — Diyanet", "quran.com id=77 Diyanet Isleri"),
    "fa": (135, "Persian — IslamHouse", "quran.com id=135 IslamHouse.com"),
    "fr": (31, "French — Muhammad Hamidullah", "quran.com id=31 Muhammad Hamidullah"),
    "ha": (32, "Hausa — Abubakar Gumi", "quran.com id=32 Abubakar Mahmoud Gumi"),
    "so": (46, "Somali — Mahmud Muhammad Abduh", "quran.com id=46 Mahmud Muhammad Abduh"),
    "ps": (118, "Pashto — Zakaria Abulsalam", "quran.com id=118 Zakaria Abulsalam"),
    "sw": (49, "Swahili — Ali Muhsin Al-Barwani", "quran.com id=49 Ali Muhsin Al-Barwani"),
}

# Urdu already imported via add_urdu_translation.py (id=54). Optionally refresh.
OPTIONAL_UR = ("ur", 54, "Maulana Muhammad Junagarhi", "quran.com id=54 Maulana Muhammad Junagarhi")


def fetch_chapter(translation_id: int, chapter: int) -> list[dict]:
    url = f"https://api.quran.com/api/v4/quran/translations/{translation_id}?chapter_number={chapter}"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "ISLAM307-translation-importer/1.0",
            "Accept": "application/json",
        },
    )
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            return data.get("translations") or []
        except Exception:
            if attempt == 5:
                raise
            time.sleep(1.2 * (attempt + 1))
    return []


def clean_html(text: str) -> str:
    text = re.sub(r"<sup[^>]*>.*?</sup>", "", text or "", flags=re.I | re.S)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def ensure_column(conn: sqlite3.Connection, lang: str, source: str) -> str:
    col = f"translation_{lang}"
    cols = {r[1] for r in conn.execute("PRAGMA table_info(ayahs)")}
    if col not in cols:
        conn.execute(f"ALTER TABLE ayahs ADD COLUMN {col} TEXT")
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (f"{col}_source", source),
    )
    return col


def import_lang(conn: sqlite3.Connection, lang: str, tid: int, source: str, sleep: float) -> tuple[int, int]:
    col = ensure_column(conn, lang, source)
    total = 0
    for surah in range(1, 115):
        rows = fetch_chapter(tid, surah)
        if not rows:
            raise RuntimeError(f"No rows for {lang} surah {surah} (id={tid})")
        expected = conn.execute(
            "SELECT COUNT(*) FROM ayahs WHERE surah_number=?", (surah,)
        ).fetchone()[0]
        if len(rows) != expected:
            raise RuntimeError(
                f"{lang} surah {surah}: got {len(rows)} translations, expected {expected} ayahs"
            )
        for i, row in enumerate(rows, start=1):
            text = clean_html(row.get("text") or "")
            if not text:
                raise RuntimeError(f"Empty {lang} text at {surah}:{i}")
            conn.execute(
                f"UPDATE ayahs SET {col}=? WHERE surah_number=? AND ayah_number=?",
                (text, surah, i),
            )
            total += 1
        conn.commit()
        print(f"  {lang} surah {surah:3d}: {len(rows)} ayahs", flush=True)
        time.sleep(sleep)
    missing = conn.execute(
        f"SELECT COUNT(*) FROM ayahs WHERE {col} IS NULL OR trim({col})=''"
    ).fetchone()[0]
    return total, missing


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--langs", default=",".join(TRANSLATIONS.keys()), help="Comma list e.g. en,hi,bn")
    ap.add_argument("--include-ur", action="store_true", help="Also refresh Urdu (id=54)")
    ap.add_argument("--sleep", type=float, default=0.12)
    args = ap.parse_args()

    conn = sqlite3.connect(args.db)
    selected = [x.strip() for x in args.langs.split(",") if x.strip()]
    results = []

    for lang in selected:
        if lang not in TRANSLATIONS:
            raise SystemExit(f"Unknown lang {lang}. Known: {', '.join(TRANSLATIONS)}")
        tid, title, source = TRANSLATIONS[lang]
        print(f"\n== Importing {lang}: {title} (id={tid}) ==")
        total, missing = import_lang(conn, lang, tid, source, args.sleep)
        results.append((lang, title, total, missing))
        print(f"Done {lang}: {total} ayahs, missing={missing}")

    if args.include_ur:
        lang, tid, title, source = OPTIONAL_UR
        print(f"\n== Refreshing {lang}: {title} (id={tid}) ==")
        total, missing = import_lang(conn, lang, tid, source, args.sleep)
        results.append((lang, title, total, missing))

    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        ("schema_version", "4_translations_multi"),
    )
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (
            "translations_offline",
            json.dumps(
                {
                    lang: {"id": tid, "title": title, "source": source}
                    for lang, (tid, title, source) in TRANSLATIONS.items()
                    if lang in selected
                },
                ensure_ascii=False,
            ),
        ),
    )
    conn.commit()
    conn.close()

    print("\nSUMMARY")
    bad = 0
    for lang, title, total, missing in results:
        print(f"  {lang}: {total} rows · missing {missing} · {title}")
        if missing:
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
