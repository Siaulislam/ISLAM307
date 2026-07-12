#!/usr/bin/env python3
"""Add authentic Urdu translation (Junagarhi) to quran.db from Quran.com API."""

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
TRANSLATION_ID = 54  # Maulana Muhammad Junagarhi (Urdu)
SOURCE = "quran.com translation_id=54 (Maulana Muhammad Junagarhi)"


def fetch_chapter(chapter: int) -> list[dict]:
    url = f"https://api.quran.com/api/v4/quran/translations/{TRANSLATION_ID}?chapter_number={chapter}"
    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307-urdu-builder/1.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            return data.get("translations") or []
        except Exception:
            if attempt == 4:
                raise
            time.sleep(1.5 * (attempt + 1))
    return []


def clean_html(text: str) -> str:
    text = re.sub(r"<sup[^>]*>.*?</sup>", "", text or "", flags=re.I | re.S)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def ensure_column(conn: sqlite3.Connection) -> None:
    cols = {r[1] for r in conn.execute("PRAGMA table_info(ayahs)")}
    if "translation_ur" not in cols:
        conn.execute("ALTER TABLE ayahs ADD COLUMN translation_ur TEXT")
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        ("translation_ur_source", SOURCE),
    )
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        ("schema_version", "2_urdu"),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    args = parser.parse_args()
    conn = sqlite3.connect(args.db)
    ensure_column(conn)
    total = 0
    for surah in range(1, 115):
        rows = fetch_chapter(surah)
        if not rows:
            raise RuntimeError(f"No Urdu rows for surah {surah}")
        for i, row in enumerate(rows, start=1):
            text = clean_html(row.get("text") or "")
            conn.execute(
                "UPDATE ayahs SET translation_ur = ? WHERE surah_number = ? AND ayah_number = ?",
                (text, surah, i),
            )
            total += 1
        conn.commit()
        print(f"surah {surah}: {len(rows)} ayahs")
        time.sleep(0.15)
    missing = conn.execute(
        "SELECT COUNT(*) FROM ayahs WHERE translation_ur IS NULL OR trim(translation_ur) = ''"
    ).fetchone()[0]
    print(f"Updated {total} ayahs; missing Urdu: {missing}")
    conn.close()
    return 0 if missing == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
