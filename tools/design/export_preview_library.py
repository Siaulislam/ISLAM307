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
    # Discover authenticated translation_* columns so preview packs stay in sync
    # with quran.db (never invent text — only export what is stored).
    cols = [
        r[1]
        for r in conn.execute("PRAGMA table_info(ayahs)")
        if r[1].startswith("translation_")
    ]
    lang_keys = sorted(c.replace("translation_", "", 1) for c in cols)
    select_cols = ", ".join(
        ["surah_number", "ayah_number", "text_uthmani", "page_madani", "juz", "ruku"]
        + [f"IFNULL({c},'') AS {c}" for c in cols]
    )
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
    ayahs = []
    for r in conn.execute(
        f"SELECT {select_cols} FROM ayahs ORDER BY global_number"
    ):
        item = {
            "s": r["surah_number"],
            "a": r["ayah_number"],
            "ar": r["text_uthmani"],
            "p": r["page_madani"],
            "j": r["juz"],
            "ruku": r["ruku"],
        }
        for lang in lang_keys:
            item[lang] = r[f"translation_{lang}"] or ""
        ayahs.append(item)
    write_json(OUT / "quran" / "surahs.json", {"surahs": surahs, "count": len(surahs)})
    write_json_gz(OUT / "quran" / "ayahs.json.gz", {"ayahs": ayahs, "count": len(ayahs)})
    return {"surahs": len(surahs), "ayahs": len(ayahs), "translations": lang_keys}


def export_quran_words() -> dict:
    """Export per-surah word knowledge for offline web preview (authenticated only)."""
    conn = sqlite3.connect(QURAN_DB)
    conn.row_factory = sqlite3.Row
    tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if "quran_words" not in tables:
        return {"surahs": 0, "words": 0}
    out_dir = OUT / "quran" / "words"
    out_dir.mkdir(parents=True, exist_ok=True)
    total = 0
    surahs = 0
    for surah in range(1, 115):
        rows = list(
            conn.execute(
                """
                SELECT id, surah, ayah, word_number, text_ar, transliteration,
                       meaning_en, meaning_ur,
                       IFNULL(meaning_hi,'') AS meaning_hi,
                       IFNULL(meaning_bn,'') AS meaning_bn,
                       IFNULL(meaning_id,'') AS meaning_id,
                       IFNULL(meaning_tr,'') AS meaning_tr,
                       IFNULL(meaning_fa,'') AS meaning_fa,
                       root, lemma, pos, morphology,
                       grammar_summary, syntax_summary, occurrence_count,
                       IFNULL(occurrence_surface,0) AS occurrence_surface,
                       IFNULL(occurrence_lemma,0) AS occurrence_lemma,
                       IFNULL(occurrence_root,0) AS occurrence_root
                FROM quran_words
                WHERE surah = ?
                ORDER BY ayah, word_number
                """,
                (surah,),
            )
        )
        if not rows:
            continue
        words = [
            {
                "id": r["id"],
                "a": r["ayah"],
                "n": r["word_number"],
                "ar": r["text_ar"] or "",
                "tr": r["transliteration"] or "",
                "en": r["meaning_en"] or "",
                "ur": r["meaning_ur"] or "",
                "hi": r["meaning_hi"] or "",
                "bn": r["meaning_bn"] or "",
                "idn": r["meaning_id"] or "",
                "trm": r["meaning_tr"] or "",
                "fa": r["meaning_fa"] or "",
                "root": r["root"] or "",
                "lemma": r["lemma"] or "",
                "pos": r["pos"] or "",
                "morph": r["morphology"] or "",
                "gram": r["grammar_summary"] or "",
                "syn": r["syntax_summary"] or "",
                "occ": r["occurrence_count"] or 0,
                "occ_s": r["occurrence_surface"] or 0,
                "occ_l": r["occurrence_lemma"] or 0,
                "occ_r": r["occurrence_root"] or 0,
            }
            for r in rows
        ]
        # parts for this surah
        ids = [w["id"] for w in words]
        parts_by = {}
        if ids and "quran_word_parts" in tables:
            qmarks = ",".join("?" * len(ids))
            for p in conn.execute(
                f"SELECT word_id, part_index, tag, features FROM quran_word_parts WHERE word_id IN ({qmarks}) ORDER BY word_id, part_index",
                ids,
            ):
                parts_by.setdefault(p["word_id"], []).append(
                    {"i": p["part_index"], "tag": p["tag"] or "", "f": p["features"] or ""}
                )
        for w in words:
            w["parts"] = parts_by.get(w["id"], [])
        write_json_gz(out_dir / f"{surah}.json.gz", {"surah": surah, "words": words, "count": len(words)})
        total += len(words)
        surahs += 1
    return {"surahs": surahs, "words": total}


def export_hadith() -> dict:
    import re
    ar_re = re.compile(r"[\u0600-\u06FF]")
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
            "SELECT id, slug, name_en, name_ar, hadith_count FROM books "
            "WHERE slug IN ('bukhari','muslim','tirmidhi','abudawud') ORDER BY sort_order"
        )
    ]
    write_json(OUT / "hadith" / "books.json", {"books": books, "count": sum(b["count"] for b in books)})
    totals = {}
    for book in books:
        rows = []
        for r in conn.execute(
            """
            SELECT h.hadith_number, h.text_ar, h.text_en, h.text_ur, h.grade, h.narrator,
                   h.reference_book, h.reference_hadith, c.number AS chapter_number, c.title AS chapter_title
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
            # Omit external Reference URL / Source Provider from preview packs.
            if isinstance(ref_detail, dict):
                ref_detail = {k: v for k, v in ref_detail.items() if k != "source_url"}
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
                }
            )
        write_json_gz(OUT / "hadith" / f"{book['slug']}.json.gz", {"book": book, "hadiths": rows})
        totals[book["slug"]] = len(rows)
    return totals


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    summary = {
        "quran": export_quran(),
        "quran_words": export_quran_words(),
        "hadith": export_hadith(),
    }
    write_json(OUT / "manifest.json", summary)
    print(json.dumps(summary, indent=2))
    print(f"Wrote preview library data -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
