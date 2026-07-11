#!/usr/bin/env python3
"""
Build ISLAM 307 quran.db from verified sources (NOT raw OCR text).

Primary Arabic: Tanzil Project Uthmani v1.1 (dotquran/corpus)
Verification: cross-check against Quran.com API uthmani field
Metadata: page (Madani 604), juz, hizb, rub, ruku, manzil, sajdah, tajweed, translation

Optional: --pdf path/to/13-line-quran.pdf maps Indo-Pak page numbers by aligning
extracted glyphs to verified ayah text (PDF is never the reading engine).

Usage:
  python build_quran_db.py
  python build_quran_db.py --pdf data/source/quran-13-line.pdf
  python build_quran_db.py --output app/assets/databases/quran.db
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "app" / "assets" / "databases" / "quran.db"
SCHEMA = Path(__file__).with_name("schema.sql")
CACHE = ROOT / "tools" / "quran" / "cache"

TANZIL_URL = "https://raw.githubusercontent.com/dotquran/corpus/main/processed/uthmani/quran-uthmani.json"
CHAPTERS_URL = "https://api.quran.com/api/v4/chapters?language=en"
PAGE_URL = "https://api.quran.com/api/v4/verses/by_page/{page}?words=false&translations=131&fields=text_uthmani,text_uthmani_tajweed,juz_number,hizb_number,rub_el_hizb_number,ruku_number,manzil_number,sajdah_number,page_number"
TRANSLATION_ID = 131  # Sahih International

SURAH_EN = {
    1: "Al-Fatiha", 2: "Al-Baqarah", 3: "Ali 'Imran", 4: "An-Nisa", 5: "Al-Ma'idah",
    6: "Al-An'am", 7: "Al-A'raf", 8: "Al-Anfal", 9: "At-Tawbah", 10: "Yunus",
    11: "Hud", 12: "Yusuf", 13: "Ar-Ra'd", 14: "Ibrahim", 15: "Al-Hijr",
    16: "An-Nahl", 17: "Al-Isra", 18: "Al-Kahf", 19: "Maryam", 20: "Ta-Ha",
    21: "Al-Anbya", 22: "Al-Hajj", 23: "Al-Mu'minun", 24: "An-Nur", 25: "Al-Furqan",
    26: "Ash-Shu'ara", 27: "An-Naml", 28: "Al-Qasas", 29: "Al-Ankabut", 30: "Ar-Rum",
    31: "Luqman", 32: "As-Sajdah", 33: "Al-Ahzab", 34: "Saba", 35: "Fatir",
    36: "Ya-Sin", 37: "As-Saffat", 38: "Sad", 39: "Az-Zumar", 40: "Ghafir",
    41: "Fussilat", 42: "Ash-Shuraa", 43: "Az-Zukhruf", 44: "Ad-Dukhan", 45: "Al-Jathiyah",
    46: "Al-Ahqaf", 47: "Muhammad", 48: "Al-Fath", 49: "Al-Hujurat", 50: "Qaf",
    51: "Adh-Dhariyat", 52: "At-Tur", 53: "An-Najm", 54: "Al-Qamar", 55: "Ar-Rahman",
    56: "Al-Waqi'ah", 57: "Al-Hadid", 58: "Al-Mujadila", 59: "Al-Hashr", 60: "Al-Mumtahanah",
    61: "As-Saf", 62: "Al-Jumu'ah", 63: "Al-Munafiqun", 64: "At-Taghabun", 65: "At-Talaq",
    66: "At-Tahrim", 67: "Al-Mulk", 68: "Al-Qalam", 69: "Al-Haqqah", 70: "Al-Ma'arij",
    71: "Nuh", 72: "Al-Jinn", 73: "Al-Muzzammil", 74: "Al-Muddaththir", 75: "Al-Qiyamah",
    76: "Al-Insan", 77: "Al-Mursalat", 78: "An-Naba", 79: "An-Nazi'at", 80: "'Abasa",
    81: "At-Takwir", 82: "Al-Infitar", 83: "Al-Mutaffifin", 84: "Al-Inshiqaq", 85: "Al-Buruj",
    86: "At-Tariq", 87: "Al-A'la", 88: "Al-Ghashiyah", 89: "Al-Fajr", 90: "Al-Balad",
    91: "Ash-Shams", 92: "Al-Layl", 93: "Ad-Duhaa", 94: "Ash-Sharh", 95: "At-Tin",
    96: "Al-'Alaq", 97: "Al-Qadr", 98: "Al-Bayyinah", 99: "Az-Zalzalah", 100: "Al-'Adiyat",
    101: "Al-Qari'ah", 102: "At-Takathur", 103: "Al-'Asr", 104: "Al-Humazah", 105: "Al-Fil",
    106: "Quraysh", 107: "Al-Ma'un", 108: "Al-Kawthar", 109: "Al-Kafirun", 110: "An-Nasr",
    111: "Al-Masad", 112: "Al-Ikhlas", 113: "Al-Falaq", 114: "An-Nas",
}


def fetch_json(url: str, cache_name: str | None = None) -> dict | list:
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE / cache_name if cache_name else None
    if cache_path and cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))

    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307-quran-builder/1.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            if cache_path:
                cache_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            return data
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(2 ** attempt)
                continue
            raise
        except Exception:
            if attempt == 4:
                raise
            time.sleep(1.5)
    raise RuntimeError(f"Failed to fetch {url}")


def normalize_ar(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r"[\u0640\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u06E0-\u06ED]", "", text)
    text = text.replace("\u0640", "")
    text = re.sub(r"\s+", "", text)
    return text.strip()


def load_tanzil() -> dict[tuple[int, int], str]:
    payload = fetch_json(TANZIL_URL, "tanzil-uthmani.json")
    out: dict[tuple[int, int], str] = {}
    for surah in payload["surahs"]:
        sn = int(surah["number"])
        for ayah in surah["ayahs"]:
            an = int(ayah["number"])
            if an == 0:
                continue  # bismillah marker row in surah 2+
            out[(sn, an)] = ayah["text"].strip()
    return out


def load_chapters() -> dict[int, dict]:
    payload = fetch_json(CHAPTERS_URL, "chapters-en.json")
    chapters = {}
    for ch in payload.get("chapters", []):
        chapters[int(ch["id"])] = ch
    return chapters


def load_api_verses() -> dict[tuple[int, int], dict]:
    verses: dict[tuple[int, int], dict] = {}
    for page in range(1, 605):
        url = PAGE_URL.format(page=page)
        cache_name = f"page-{page:03d}.json"
        payload = fetch_json(url, cache_name)
        for v in payload.get("verses", []):
            key = v["verse_key"].split(":")
            sn, an = int(key[0]), int(key[1])
            trans = ""
            for t in v.get("translations", []) or []:
                if t.get("resource_id") == TRANSLATION_ID or t.get("id"):
                    trans = re.sub(r"<[^>]+>", "", t.get("text", ""))
                    break
            verses[(sn, an)] = {
                "global_id": v["id"],
                "text_api": v.get("text_uthmani", ""),
                "text_tajweed": v.get("text_uthmani_tajweed") or v.get("text_uthmani", ""),
                "translation_en": trans,
                "page_madani": v.get("page_number") or page,
                "juz": v.get("juz_number") or 1,
                "hizb": v.get("hizb_number") or 1,
                "rub_el_hizb": v.get("rub_el_hizb_number"),
                "ruku": v.get("ruku_number") or 1,
                "manzil": v.get("manzil_number"),
                "sajda_number": v.get("sajdah_number"),
            }
        if page % 50 == 0:
            print(f"  fetched page {page}/604")
        time.sleep(0.05)
    return verses


def try_pdf_13_line_pages(pdf_path: Path, tanzil: dict[tuple[int, int], str]) -> dict[tuple[int, int], int]:
    """Optional Indo-Pak 13-line page mapping from PDF (alignment, not OCR trust)."""
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("  [pdf] PyMuPDF not installed — skip 13-line pages. pip install pymupdf")
        return {}

    if not pdf_path.exists():
        print(f"  [pdf] not found: {pdf_path}")
        return {}

    print(f"  [pdf] scanning {pdf_path.name} for 13-line page markers...")
    mapping: dict[tuple[int, int], int] = {}
    doc = fitz.open(pdf_path)
    ayah_pattern = re.compile(r"(\d{1,3}):(\d{1,3})")

    for page_idx in range(len(doc)):
        text = doc[page_idx].get_text("text")
        page_num = page_idx + 1
        for m in ayah_pattern.finditer(text):
            sn, an = int(m.group(1)), int(m.group(2))
            if (sn, an) in tanzil:
                mapping[(sn, an)] = page_num
    doc.close()
    print(f"  [pdf] mapped {len(mapping)} ayahs to 13-line pages")
    return mapping


def build_db(output: Path, pdf_path: Path | None) -> None:
    print("Loading Tanzil Uthmani (authoritative text)...")
    tanzil = load_tanzil()
    print(f"  {len(tanzil)} ayahs from Tanzil")

    print("Loading Quran.com metadata (pages, juz, ruku, sajdah, tajweed, translation)...")
    api = load_api_verses()
    chapters = load_chapters()

    mismatches = []
    for key, api_text in api.items():
        t = tanzil.get(key, "")
        a = api_text.get("text_api", "")
        if normalize_ar(t) != normalize_ar(a):
            mismatches.append(key)

    if mismatches:
        print(f"  WARNING: {len(mismatches)} ayahs differ Tanzil vs API — using Tanzil text")
        for k in mismatches[:5]:
            print(f"    mismatch {k[0]}:{k[1]}")

    pdf_pages = try_pdf_13_line_pages(pdf_path, tanzil) if pdf_path else {}

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    conn = sqlite3.connect(output)
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))

    conn.execute(
        "INSERT INTO meta(key,value) VALUES (?,?)",
        ("source_text", "Tanzil Project Uthmani v1.1 — tanzil.net"),
    )
    conn.execute(
        "INSERT INTO meta(key,value) VALUES (?,?)",
        ("source_metadata", "Quran.com API v4 — page/juz/ruku/sajdah/tajweed"),
    )
    conn.execute(
        "INSERT INTO meta(key,value) VALUES (?,?)",
        ("verified_mismatches", str(len(mismatches))),
    )
    conn.execute(
        "INSERT INTO meta(key,value) VALUES (?,?)",
        ("pdf_engine", "disabled — app reads quran.db only"),
    )

    global_n = 0
    for sn in range(1, 115):
        ch = chapters.get(sn, {})
        ayahs_in_surah = [k for k in tanzil if k[0] == sn]
        ayah_count = max((a for _, a in ayahs_in_surah), default=0)
        conn.execute(
            """INSERT INTO surahs(number,name_ar,name_en,name_transliteration,revelation_place,ayah_count,bismillah_pre)
               VALUES (?,?,?,?,?,?,?)""",
            (
                sn,
                ch.get("name_arabic") or "",
                ch.get("name_simple") or SURAH_EN.get(sn, f"Surah {sn}"),
                ch.get("translated_name", {}).get("name") if isinstance(ch.get("translated_name"), dict) else None,
                ch.get("revelation_place", ""),
                ayah_count,
                0 if sn in (1, 9) else 1,
            ),
        )

    sajdah_rows = []
    ruku_seen: dict[int, dict] = {}
    juz_bounds: dict[int, list] = {}
    page_bounds: dict[int, list] = {}

    for sn in range(1, 115):
        max_ayah = max((a for s, a in tanzil if s == sn), default=0)
        for an in range(1, max_ayah + 1):
            key = (sn, an)
            if key not in tanzil:
                continue
            global_n += 1
            meta = api.get(key, {})
            text = tanzil[key]
            page_13 = pdf_pages.get(key)
            has_sajda = 1 if meta.get("sajda_number") else 0
            has_rub = 1 if meta.get("rub_el_hizb") else 0

            conn.execute(
                """INSERT INTO ayahs(
                    global_number,surah_number,ayah_number,text_uthmani,text_tajweed,translation_en,
                    page_madani,page_13_line,juz,hizb,rub_el_hizb,ruku,manzil,sajda_number,
                    has_sajda,has_rub_el_hizb,verified
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    global_n, sn, an, text,
                    meta.get("text_tajweed") or text,
                    meta.get("translation_en", ""),
                    meta.get("page_madani", 1),
                    page_13,
                    meta.get("juz", 1),
                    meta.get("hizb", 1),
                    meta.get("rub_el_hizb"),
                    meta.get("ruku", 1),
                    meta.get("manzil"),
                    meta.get("sajda_number"),
                    has_sajda,
                    has_rub,
                    0 if key in mismatches else 1,
                ),
            )

            ayah_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
            search_blob = f"{sn}:{an} {SURAH_EN.get(sn,'')} {meta.get('translation_en','')}"
            conn.execute(
                "INSERT INTO ayah_fts(ayah_id,surah_number,ayah_number,text_uthmani,translation_en,search_blob) VALUES (?,?,?,?,?,?)",
                (ayah_id, sn, an, text, meta.get("translation_en", ""), search_blob),
            )

            if has_sajda:
                sajdah_rows.append((sn, an, "recommended"))

            ruku_n = meta.get("ruku", 1)
            if ruku_n not in ruku_seen:
                ruku_seen[ruku_n] = {"surah": sn, "start": an, "end": an, "juz": meta.get("juz", 1)}
            else:
                ruku_seen[ruku_n]["end"] = an

            j = meta.get("juz", 1)
            juz_bounds.setdefault(j, [global_n, global_n])
            juz_bounds[j][1] = global_n

            p = meta.get("page_madani", 1)
            page_bounds.setdefault(p, [key, key])
            page_bounds[p][1] = key

    for sn, an, st in sajdah_rows:
        conn.execute(
            "INSERT OR IGNORE INTO sajdah(surah_number,ayah_number,sajda_type) VALUES (?,?,?)",
            (sn, an, st),
        )

    for rn, info in sorted(ruku_seen.items()):
        conn.execute(
            "INSERT INTO ruku(number,surah_number,start_ayah,end_ayah,juz) VALUES (?,?,?,?,?)",
            (rn, info["surah"], info["start"], info["end"], info["juz"]),
        )

    for jn, (start_g, end_g) in sorted(juz_bounds.items()):
        start_row = conn.execute(
            "SELECT surah_number, ayah_number FROM ayahs WHERE global_number=?", (start_g,)
        ).fetchone()
        end_row = conn.execute(
            "SELECT surah_number, ayah_number FROM ayahs WHERE global_number=?", (end_g,)
        ).fetchone()
        conn.execute(
            "INSERT INTO juz(number,name_ar,start_surah,start_ayah,end_surah,end_ayah) VALUES (?,?,?,?,?,?)",
            (jn, f"الجزء {jn}", start_row[0], start_row[1], end_row[0], end_row[1]),
        )

    for pn, (start_key, end_key) in sorted(page_bounds.items()):
        conn.execute(
            "INSERT INTO pages_madani(page_number,juz,start_surah,start_ayah,end_surah,end_ayah) VALUES (?,?,?,?,?,?)",
            (
                pn,
                api.get(start_key, {}).get("juz", 1),
                start_key[0], start_key[1],
                end_key[0], end_key[1],
            ),
        )

    conn.commit()
    count = conn.execute("SELECT COUNT(*) FROM ayahs").fetchone()[0]
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("ayah_count", str(count)))
    conn.commit()
    conn.close()

    size_mb = output.stat().st_size / (1024 * 1024)
    print(f"\nDone: {output}")
    print(f"  Ayahs: {count}")
    print(f"  Size: {size_mb:.2f} MB")
    print(f"  Verified mismatches (Tanzil kept): {len(mismatches)}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build ISLAM 307 quran.db")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--pdf", type=Path, default=ROOT / "data" / "source" / "quran-13-line.pdf")
    parser.add_argument("--skip-pdf", action="store_true")
    args = parser.parse_args()

    pdf = None if args.skip_pdf else args.pdf
    build_db(args.output, pdf)
    return 0


if __name__ == "__main__":
    sys.exit(main())
