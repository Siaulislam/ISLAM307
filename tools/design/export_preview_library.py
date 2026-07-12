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

import sys

sys.path.insert(0, str(ROOT / "tools" / "hadith"))
from hadith_meta import (  # noqa: E402
    build_reference_detail,
    extract_ravi_by_lang,
    isnad_by_lang,
)



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
            "ur": (r["translation_ur"] if "translation_ur" in r.keys() else "") or "",
            "p": r["page_madani"],
            "j": r["juz"],
            "ruku": r["ruku"],
        }
        for r in conn.execute(
            "SELECT surah_number, ayah_number, text_uthmani, translation_en, "
            "IFNULL(translation_ur,'') AS translation_ur, page_madani, juz, ruku FROM ayahs ORDER BY global_number"
        )
    ]
    write_json(OUT / "quran" / "surahs.json", {"surahs": surahs, "count": len(surahs)})
    write_json_gz(OUT / "quran" / "ayahs.json.gz", {"ayahs": ayahs, "count": len(ayahs)})
    return {"surahs": len(surahs), "ayahs": len(ayahs)}


def export_hadith() -> dict:
    import re
    ar_re = re.compile(r"[\u0600-\u06FF]")
    conn = connect_gz(HADITH_GZ)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadiths)")}
    has_ref_url = "reference_url" in cols
    has_provider = "source_provider" in cols
    books = [
        {
            "id": r["id"],
            "slug": r["slug"],
            "en": r["name_en"],
            "ar": r["name_ar"],
            "count": r["hadith_count"],
        }
        for r in conn.execute(
            "SELECT id, slug, name_en, name_ar, hadith_count FROM books "
            "WHERE slug IN ('bukhari','muslim','tirmidhi','abudawud') ORDER BY sort_order"
        )
    ]
    write_json(OUT / "hadith" / "books.json", {"books": books, "count": sum(b["count"] for b in books)})
    totals = {}
    for book in books:
        rows = []
        select_extra = ""
        if has_ref_url:
            select_extra += ", h.reference_url"
        if has_provider:
            select_extra += ", h.source_provider"
        for r in conn.execute(
            f"""
            SELECT h.hadith_number, h.text_ar, h.text_en, h.text_ur, h.grade, h.narrator,
                   h.reference_book, h.reference_hadith, c.number AS chapter_number, c.title AS chapter_title
                   {select_extra}
            FROM hadiths h
            LEFT JOIN chapters c ON c.id = h.chapter_id
            WHERE h.book_id = ?
            ORDER BY h.hadith_number
            """,
            (book["id"],),
        ):
            ref_book = r["reference_book"]
            ref_hadith = r["reference_hadith"] or r["hadith_number"]
            reference = f"{book['en']} · Hadith {ref_hadith}"
            if ref_book not in (None, 0, "0"):
                reference = f"{book['en']} · Book {ref_book} · Hadith {ref_hadith}"
            ravi_primary = (r["narrator"] or "").strip()
            text_ar = (r["text_ar"] or "").strip()
            if text_ar and not ar_re.search(text_ar):
                text_ar = ""
            ravi_by_lang = extract_ravi_by_lang(
                text_ar,
                ravi_primary,
                r["text_en"] or "",
                r["text_ur"] or "",
            )
            isnads = isnad_by_lang(text_ar, r["text_en"] or "", r["text_ur"] or "")
            ref_detail = build_reference_detail(
                book_name=book["en"],
                book_slug=book["slug"],
                book_name_ar=book.get("ar") or "",
                hadith_number=r["hadith_number"],
                reference_book=ref_book,
                reference_hadith=ref_hadith,
                chapter_title=r["chapter_title"],
                chapter_number=r["chapter_number"],
                grade=r["grade"],
            )
            source_url = ""
            if has_ref_url:
                source_url = (r["reference_url"] or "").strip()
            if not source_url:
                source_url = ref_detail["source_url"]
            provider = ""
            if has_provider:
                provider = (r["source_provider"] or "").strip()
            if not provider:
                provider = "fawazahmed0/hadith-api@1"
            rows.append(
                {
                    "n": r["hadith_number"],
                    "ar": text_ar,
                    "en": r["text_en"] or "",
                    "ur": r["text_ur"] or "",
                    "grade": r["grade"] or "",
                    "ravi": ravi_primary,
                    "narrator": ravi_primary,
                    "ravi_chain": ravi_by_lang.get("ar") or [],
                    "ravi_by_lang": ravi_by_lang,
                    "isnad": isnads.get("ar") or "",
                    "isnad_ur": isnads.get("ur") or "",
                    "isnad_by_lang": isnads,
                    "reference": reference,
                    "reference_detail": ref_detail,
                    "reference_book": ref_book,
                    "reference_hadith": ref_hadith,
                    "kitab": r["chapter_title"] or "",
                    "kitab_number": r["chapter_number"],
                    "source_url": source_url,
                    "reference_url": source_url,
                    "source_provider": provider,
                }
            )
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
