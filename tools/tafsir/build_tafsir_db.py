#!/usr/bin/env python3
"""Build ISLAM 307 tafsir.db — multi-source, offline FTS5."""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sqlite3
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("tafsir_sources.json")
SCHEMA = Path(__file__).with_name("schema.sql")
CACHE = ROOT / "tools" / "tafsir" / "cache"
DEFAULT_OUT = ROOT / "app" / "assets" / "databases" / "tafsir.db"

TAFSIR_BY_AYAH = "https://api.qurancdn.com/api/qdc/tafsirs/{resource_id}/by_ayah/{surah}:{ayah}"


def fetch_json(url: str, cache_name: str) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / cache_name
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307-tafsir-builder/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            return data
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                time.sleep(2 ** attempt)
                continue
            raise
        except Exception:
            if attempt == 3:
                raise
            time.sleep(1)
    raise RuntimeError(url)


def ayah_counts() -> dict[int, int]:
    """Load surah ayah counts from quran.db if present, else standard."""
    qpath = ROOT / "app" / "assets" / "databases" / "quran.db"
    if qpath.exists():
        conn = sqlite3.connect(qpath)
        rows = conn.execute("SELECT number, ayah_count FROM surahs ORDER BY number").fetchall()
        conn.close()
        return {r[0]: r[1] for r in rows}
    return {
        1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75, 9: 129, 10: 109,
        11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128, 17: 111, 18: 110, 19: 98, 20: 135,
        21: 112, 22: 78, 23: 118, 24: 64, 25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60,
        31: 34, 32: 30, 33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
        41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29, 49: 18, 50: 45,
        51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96, 57: 29, 58: 22, 59: 24, 60: 13,
        61: 14, 62: 11, 63: 11, 64: 18, 65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44,
        71: 28, 72: 28, 73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
        81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26, 89: 30, 90: 20,
        91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19, 97: 5, 98: 8, 99: 8, 100: 11,
        101: 11, 102: 8, 103: 3, 104: 9, 105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3,
        111: 5, 112: 4, 113: 5, 114: 6,
    }


def build(output: Path, full: bool = False) -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    counts = ayah_counts()

    if output.exists():
        output.unlink()
    output.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(output)
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("builder", "ISLAM307 tafsir builder"))
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("offline", "true"))

    total = 0
    for order, src in enumerate(manifest["sources"], start=1):
        slug = src["slug"]
        rid = src["api_resource_id"]
        conn.execute(
            "INSERT INTO sources(id, slug, name_en, name_ar, author, language, sort_order) VALUES (?,?,?,?,?,?,?)",
            (order, slug, src["name_en"], src.get("name_ar"), src.get("author"), src.get("language", "en"), order),
        )
        source_id = order
        print(f"Fetching {src['name_en']}...")

        surah_range = range(1, 115) if full else range(1, 4)  # default: Al-Fatiha + Al-Baqarah partial for dev
        max_ayah = 20 if not full else None

        for surah in surah_range:
            limit = counts.get(surah, 0)
            if max_ayah and surah == 2:
                limit = min(limit, max_ayah)
            for ayah in range(1, limit + 1):
                cache = f"tafsir-{rid}-{surah}-{ayah}.json"
                url = TAFSIR_BY_AYAH.format(resource_id=rid, surah=surah, ayah=ayah)
                try:
                    payload = fetch_json(url, cache)
                except Exception:
                    continue
                tafsir_obj = payload.get("tafsir") or {}
                if isinstance(tafsir_obj, list):
                    text = tafsir_obj[0].get("text", "") if tafsir_obj else ""
                else:
                    text = tafsir_obj.get("text") or ""
                text = re.sub(r"<[^>]+>", " ", text)
                text = re.sub(r"\s+", " ", text).strip()
                if not text:
                    continue
                conn.execute(
                    "INSERT INTO entries(source_id, surah_number, ayah_number, text) VALUES (?,?,?,?)",
                    (source_id, surah, ayah, text),
                )
                eid = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
                conn.execute(
                    "INSERT INTO tafsir_fts(entry_id, source_slug, surah_number, ayah_number, text, search_blob) VALUES (?,?,?,?,?,?)",
                    (eid, slug, surah, ayah, text, f"{src['name_en']} {surah}:{ayah}"),
                )
                total += 1
                if total % 100 == 0:
                    print(f"  {total} entries...", flush=True)
                time.sleep(0.03 if full else 0.05)

    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("entry_count", str(total)))
    conn.commit()
    conn.close()

    # Compress for GitHub asset limit (<100MB)
    gz_path = output.with_suffix(output.suffix + ".gz")
    with open(output, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        f_out.write(f_in.read())

    print(f"\nDone: {output} ({total} entries, {output.stat().st_size / 1024:.1f} KB)")
    print(f"  Compressed: {gz_path} ({gz_path.stat().st_size / 1024 / 1024:.2f} MB)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--full", action="store_true", help="Fetch all 6236 ayahs (slow, ~3h)")
    args = parser.parse_args()
    build(args.output, full=args.full)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
