#!/usr/bin/env python3
"""Export compact JSON packs for the GitHub Pages / local web library."""

from __future__ import annotations

import gzip
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "preview" / "library" / "data"
QURAN_DB = ROOT / "app" / "assets" / "databases" / "quran.db"
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
TAFSIR_GZ = ROOT / "app" / "assets" / "databases" / "tafsir.db.gz"


def connect_gz(path: Path) -> sqlite3.Connection:
    raw = gzip.decompress(path.read_bytes())
    tmp = Path("/tmp") / f"islam307_{path.stem}.db"
    tmp.write_bytes(raw)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def write_json_gz(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    path.write_bytes(gzip.compress(data, compresslevel=9))


def export_quran() -> dict:
    conn = sqlite3.connect(QURAN_DB)
    conn.row_factory = sqlite3.Row
    surahs = [
        {
            "n": r["number"],
            "en": r["name_en"],
            "ar": r["name_ar"],
            "ayahs": r["ayah_count"],
            "place": r["revelation_place"],
        }
        for r in conn.execute(
            "SELECT number, name_en, name_ar, ayah_count, revelation_place FROM surahs ORDER BY number"
        )
    ]
    ayahs = [
        {
            "s": r["surah_number"],
            "a": r["ayah_number"],
            "ar": r["text_uthmani"],
            "en": r["translation_en"] or "",
            "p": r["page_madani"],
            "j": r["juz"],
        }
        for r in conn.execute(
            "SELECT surah_number, ayah_number, text_uthmani, translation_en, page_madani, juz FROM ayahs ORDER BY global_number"
        )
    ]
    write_json(OUT / "quran" / "surahs.json", {"surahs": surahs, "count": len(surahs)})
    write_json_gz(OUT / "quran" / "ayahs.json.gz", {"ayahs": ayahs, "count": len(ayahs)})
    return {"surahs": len(surahs), "ayahs": len(ayahs)}


def export_hadith() -> dict:
    conn = connect_gz(HADITH_GZ)
    books = [
        {
            "id": r["id"],
            "slug": r["slug"],
            "en": r["name_en"],
            "ar": r["name_ar"],
            "count": r["hadith_count"],
        }
        for r in conn.execute(
            "SELECT id, slug, name_en, name_ar, hadith_count FROM books ORDER BY sort_order"
        )
    ]
    write_json(OUT / "hadith" / "books.json", {"books": books, "count": sum(b["count"] for b in books)})
    totals = {}
    for book in books:
        rows = [
            {
                "n": r["hadith_number"],
                "ar": r["text_ar"] or "",
                "en": r["text_en"] or "",
                "grade": r["grade"] or "",
                "narrator": r["narrator"] or "",
            }
            for r in conn.execute(
                """
                SELECT hadith_number, text_ar, text_en, grade, narrator
                FROM hadiths WHERE book_id = ? ORDER BY hadith_number
                """,
                (book["id"],),
            )
        ]
        write_json_gz(OUT / "hadith" / f"{book['slug']}.json.gz", {"book": book, "hadiths": rows})
        totals[book["slug"]] = len(rows)
    return totals


def export_tafsir() -> dict:
    conn = connect_gz(TAFSIR_GZ)
    sources = [
        {
            "id": r["id"],
            "slug": r["slug"],
            "en": r["name_en"],
            "ar": r["name_ar"],
            "author": r["author"],
            "lang": r["language"],
        }
        for r in conn.execute(
            "SELECT id, slug, name_en, name_ar, author, language FROM sources ORDER BY sort_order"
        )
    ]
    write_json(OUT / "tafsir" / "sources.json", {"sources": sources})
    counts = {}
    for source in sources:
        rows = [
            {"s": r["surah_number"], "a": r["ayah_number"], "text": r["text"]}
            for r in conn.execute(
                "SELECT surah_number, ayah_number, text FROM entries WHERE source_id = ? ORDER BY surah_number, ayah_number",
                (source["id"],),
            )
        ]
        write_json_gz(OUT / "tafsir" / f"{source['slug']}.json.gz", {"source": source, "entries": rows})
        counts[source["slug"]] = len(rows)
    return counts


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    summary = {
        "quran": export_quran(),
        "hadith": export_hadith(),
        "tafsir": export_tafsir(),
    }
    write_json(OUT / "manifest.json", summary)
    print(json.dumps(summary, indent=2))
    print(f"Wrote preview library data -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
