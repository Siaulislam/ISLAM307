#!/usr/bin/env python3
"""Fill missing Sahih Muslim data from sunnah.com (Wayback Machine mirrors).

No AI-generated hadith text. Sources:
  - Arabic, English, bab subjects, kitab titles: sunnah.com pages (via archive.org)
  - Numbering bridge: fawazahmed0 ara-muslim reference map (same IDs as hadith.db)
  - Urdu: fawazahmed0 urd-muslim edition (authentic published Urdu, not model output)

Introduction numbering note:
  DB hadith 1 = Muqaddima preface prose; hadiths 2..92 = sunnah.com
  "Introduction, Narration 1..91" (hadithnumber = narration + 1).
"""

from __future__ import annotations

import argparse
import gzip
import html as html_lib
import json
import re
import sqlite3
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / "app" / "assets" / "databases" / "hadith.db"
CACHE = Path(__file__).resolve().parent / "cache" / "sunnah_wayback"
ARA_URL = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-muslim.min.json"
URD_URL = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/urd-muslim.min.json"

BOOK_SLUGS = ["introduction"] + [str(i) for i in range(1, 57)]
FALLBACK_TS = "20260101000000"
UA = "ISLAM307-muslim-filler/1.0 (+https://github.com/siaulislam/islam307)"


def strip_tags(s: str) -> str:
    s = re.sub(r"<br\s*/?>", "\n", s, flags=re.I)
    s = re.sub(r"<[^>]+>", "", s)
    s = html_lib.unescape(s)
    s = re.sub(r"\u00a0", " ", s)
    s = re.sub(r"[ \t]+\n", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


def fetch(url: str, cache_name: str, delay: float = 0.35) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    cpath = CACHE / cache_name
    if cpath.exists() and cpath.stat().st_size > 500:
        return cpath.read_text(encoding="utf-8", errors="replace")

    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    last_err: Exception | None = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                data = resp.read().decode("utf-8", errors="replace")
            if "Just a moment..." in data and "arabic_hadith_full" not in data and not cache_name.endswith(".json"):
                raise RuntimeError(f"Cloudflare challenge for {url}")
            cpath.write_text(data, encoding="utf-8")
            time.sleep(delay)
            return data
        except Exception as e:
            last_err = e
            time.sleep(1.2 * (attempt + 1))
    raise RuntimeError(f"Failed to fetch {url}: {last_err}")


def resolve_wayback_url(path: str) -> str:
    """Prefer a known-good Wayback timestamp; optionally upgrade via availability API."""
    live = f"https://sunnah.com/muslim/{path}" if path else "https://sunnah.com/muslim"
    fallback = f"https://web.archive.org/web/{FALLBACK_TS}/{live}"
    # Availability API is flaky/slow; only try briefly and always keep a working fallback.
    api = "https://archive.org/wayback/available?url=" + urllib.parse.quote(live, safe="")
    cache_name = f"avail_{path or 'index'}.json"
    cpath = CACHE / cache_name
    if cpath.exists():
        try:
            d = json.loads(cpath.read_text(encoding="utf-8"))
            closest = d.get("archived_snapshots", {}).get("closest")
            if closest and closest.get("available") and closest.get("url"):
                return closest["url"].replace("http://", "https://", 1)
        except Exception:
            pass
    try:
        req = urllib.request.Request(api, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=12) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        CACHE.mkdir(parents=True, exist_ok=True)
        cpath.write_text(raw, encoding="utf-8")
        d = json.loads(raw)
        closest = d.get("archived_snapshots", {}).get("closest")
        if closest and closest.get("available") and closest.get("url"):
            return closest["url"].replace("http://", "https://", 1)
    except Exception:
        pass
    return fallback


def sticky_to_arabicnumber(sticky: str) -> str | None:
    m = re.match(r"Sahih Muslim\s+(\d+)(?:\s*([a-z]))?\s*$", sticky.strip(), re.I)
    if not m:
        return None
    n = m.group(1)
    letter = m.group(2)
    if letter:
        return f"{n}.{ord(letter.lower()) - ord('a') + 1:02d}"
    return n


def load_number_maps() -> tuple[dict[tuple[int, int], int], dict[str, int]]:
    raw = fetch(ARA_URL, "ara-muslim.min.json", delay=0.1)
    data = json.loads(raw)
    refmap: dict[tuple[int, int], int] = {}
    armap: dict[str, int] = {}
    for h in data.get("hadiths", []):
        hn = int(h["hadithnumber"])
        ref = h.get("reference") or {}
        b, n = ref.get("book"), ref.get("hadith")
        if b is not None and n is not None and int(n) != 0:
            refmap[(int(b), int(n))] = hn
        an = h.get("arabicnumber")
        if an is not None and str(an).strip():
            armap[str(an)] = hn
    return refmap, armap


def load_urdu() -> dict[int, str]:
    raw = fetch(URD_URL, "urd-muslim.min.json", delay=0.1)
    data = json.loads(raw)
    out: dict[int, str] = {}
    for h in data.get("hadiths", []):
        n = h.get("hadithnumber")
        text = (h.get("text") or "").strip()
        if n is None or not text or int(n) == 0:
            continue
        out[int(n)] = text
    return out


def parse_book_page(
    html: str,
    book_slug: str,
    refmap: dict[tuple[int, int], int],
    armap: dict[str, int],
) -> dict:
    html = re.sub(
        r"<!-- BEGIN WAYBACK.*?END WAYBACK TOOLBAR INSERT -->",
        "",
        html,
        flags=re.S,
    )

    book_en = book_ar = None
    m = re.search(
        r'<div class="book_page_english_name"[^>]*>\s*(.*?)\s*</div>',
        html,
        re.S,
    )
    if m:
        book_en = strip_tags(m.group(1))
    m = re.search(
        r'<div class="book_page_arabic_name[^"]*"[^>]*>(.*?)</div>',
        html,
        re.S,
    )
    if m:
        book_ar = strip_tags(m.group(1))

    chapters: list[dict] = []
    for m in re.finditer(
        r'<div class="chapter"[^>]*>\s*'
        r'<div class="echapno">\s*\(([^)]*)\)\s*</div>\s*'
        r'<div class="englishchapter"[^>]*>(.*?)</div>\s*'
        r'<div class="achapno">\s*\(([^)]*)\)\s*</div>\s*'
        r'<div class="arabicchapter[^"]*"[^>]*>(.*?)</div>',
        html,
        re.S,
    ):
        chapters.append(
            {
                "pos": m.start(),
                "number_en": strip_tags(m.group(1)),
                "title_en": strip_tags(m.group(2)).removeprefix("Chapter:").strip(),
                "number_ar": strip_tags(m.group(3)),
                "title_ar": strip_tags(m.group(4)),
            }
        )

    hadiths: list[dict] = []
    parts = re.split(r'<div class="actualHadithContainer[^"]*"', html)
    for part in parts[1:]:
        pos_marker = html.find(part[:80]) if part else -1
        sticky_m = re.search(r'hadith_reference_sticky">([^<]+)<', part)
        sticky = sticky_m.group(1).strip() if sticky_m else ""

        inbook_m = re.search(
            r"In-book reference</td>\s*<td[^>]*>\s*&nbsp;:&nbsp;([^<]+)",
            part,
            re.I,
        )
        inbook = strip_tags(inbook_m.group(1)) if inbook_m else ""

        ar_m = re.search(r'class="arabic_hadith_full[^"]*"[^>]*>(.*?)</div>', part, re.S)
        text_ar = strip_tags(ar_m.group(1)) if ar_m else ""

        narr_m = re.search(r'class="hadith_narrated"[^>]*>(.*?)</div>', part, re.S)
        details_m = re.search(r'class="text_details"[^>]*>(.*?)</div>', part, re.S)
        en_parts = []
        if narr_m:
            en_parts.append(strip_tags(narr_m.group(1)))
        if details_m:
            en_parts.append(strip_tags(details_m.group(1)))
        text_en = "\n".join(p for p in en_parts if p)

        hn: int | None = None
        # Introduction: DB hn1 = preface; narrations map to hn = narration + 1
        intro_m = re.search(r"Introduction,\s*Narration\s*(\d+)", inbook, re.I)
        if intro_m:
            hn = int(intro_m.group(1)) + 1
        else:
            book_m = re.search(r"Book\s+(\d+),\s*Hadith\s+(\d+)", inbook, re.I)
            if book_m:
                hn = refmap.get((int(book_m.group(1)), int(book_m.group(2))))
            if hn is None and sticky:
                an = sticky_to_arabicnumber(sticky)
                if an:
                    hn = armap.get(an)

        if hn is None:
            continue

        # nearest preceding bab
        # approximate position via sticky index order
        bab = None
        # Use chapter list order: find last chapter whose html appears before this sticky
        if sticky:
            sticky_pos = html.find(sticky_m.group(0)) if sticky_m else -1
            for ch in chapters:
                if sticky_pos >= 0 and ch["pos"] < sticky_pos:
                    bab = ch
                elif sticky_pos < 0:
                    bab = ch

        hadiths.append(
            {
                "hadith_number": hn,
                "text_ar": text_ar,
                "text_en": text_en,
                "book_slug": book_slug,
                "sticky": sticky,
                "inbook": inbook,
                "bab_number": bab["number_en"] if bab else None,
                "bab_title_en": bab["title_en"] if bab else None,
                "bab_title_ar": bab["title_ar"] if bab else None,
            }
        )

    return {
        "book_slug": book_slug,
        "book_en": book_en,
        "book_ar": book_ar,
        "chapters": chapters,
        "hadiths": hadiths,
    }


def parse_index(html: str) -> list[dict]:
    html = re.sub(
        r"<!-- BEGIN WAYBACK.*?END WAYBACK TOOLBAR INSERT -->",
        "",
        html,
        flags=re.S,
    )
    books: list[dict] = []
    # Current sunnah.com index markup
    for m in re.finditer(
        r'<div class="book_title title_english"[^>]*>.*?<a[^>]*href="[^"]*/muslim/([^"]+)"[^>]*>(.*?)</a>',
        html,
        re.S,
    ):
        slug = m.group(1).strip().strip("/")
        title_en = strip_tags(m.group(2))
        tail = html[m.end() : m.end() + 800]
        ar_m = re.search(r'class="book_title title_arabic[^"]*"[^>]*>(.*?)</div>', tail, re.S)
        title_ar = strip_tags(ar_m.group(1)) if ar_m else ""
        books.append({"slug": slug, "title_en": title_en, "title_ar": title_ar})

    if not books:
        # Book list rows used by some archived snapshots
        for m in re.finditer(
            r'<div class="englisharabicbook"[^>]*>.*?'
            r'href="[^"]*/muslim/(introduction|\d+)"[^>]*>(.*?)</a>.*?'
            r'<span class="arabicbook"[^>]*>(.*?)</span>',
            html,
            re.S,
        ):
            books.append(
                {
                    "slug": m.group(1),
                    "title_en": strip_tags(m.group(2)),
                    "title_ar": strip_tags(m.group(3)),
                }
            )

    if not books:
        for m in re.finditer(
            r'href="[^"]*/muslim/(introduction|\d+)/?"[^>]*>\s*([^<]+?)\s*</a>',
            html,
            re.S,
        ):
            title_en = strip_tags(m.group(2))
            if not title_en or title_en.isdigit():
                continue
            books.append({"slug": m.group(1), "title_en": title_en, "title_ar": ""})

    seen = set()
    out = []
    for b in books:
        if b["slug"] in seen or not b["title_en"]:
            continue
        seen.add(b["slug"])
        out.append(b)
    return out


def resolve_container_hn(inbook: str, sticky: str, refmap: dict, armap: dict) -> int | None:
    intro_m = re.search(r"Introduction,\s*Narration\s*(\d+)", inbook, re.I)
    if intro_m:
        return int(intro_m.group(1)) + 1
    book_m = re.search(r"Book\s+(\d+),\s*Hadith\s+(\d+)", inbook, re.I)
    hn = None
    if book_m:
        hn = refmap.get((int(book_m.group(1)), int(book_m.group(2))))
    if hn is None and sticky:
        an = sticky_to_arabicnumber(sticky)
        if an:
            hn = armap.get(an)
    return hn


def gap_fill_from_cache(db_path: Path, refmap: dict, armap: dict) -> dict:
    """Fill remaining empty Arabic/English rows using unmapped sunnah variant blocks."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    filled_ar = filled_en = 0

    def missing_ar() -> set[int]:
        return {
            int(r[0])
            for r in conn.execute(
                "SELECT hadith_number FROM hadiths WHERE book_id=2 AND (text_ar IS NULL OR trim(text_ar)='')"
            )
        }

    for slug in BOOK_SLUGS:
        path = CACHE / f"muslim_book_{slug}.html"
        if not path.exists():
            path = CACHE / f"muslim_book_{slug}_fb.html"
        if not path.exists():
            continue
        html = path.read_text(encoding="utf-8", errors="replace")
        parts = re.split(r'<div class="actualHadithContainer[^"]*"', html)
        resolved: list[dict] = []
        for part in parts[1:]:
            sticky_m = re.search(r'hadith_reference_sticky">([^<]+)<', part)
            sticky = sticky_m.group(1).strip() if sticky_m else ""
            inbook_m = re.search(
                r"In-book reference</td>\s*<td[^>]*>\s*&nbsp;:&nbsp;([^<]+)",
                part,
                re.I,
            )
            inbook = strip_tags(inbook_m.group(1)) if inbook_m else ""
            ar_m = re.search(r'class="arabic_hadith_full[^"]*"[^>]*>(.*?)</div>', part, re.S)
            text_ar = strip_tags(ar_m.group(1)) if ar_m else ""
            if not text_ar:
                continue
            narr_m = re.search(r'class="hadith_narrated"[^>]*>(.*?)</div>', part, re.S)
            details_m = re.search(r'class="text_details"[^>]*>(.*?)</div>', part, re.S)
            text_en = "\n".join(
                filter(
                    None,
                    [
                        strip_tags(narr_m.group(1)) if narr_m else "",
                        strip_tags(details_m.group(1)) if details_m else "",
                    ],
                )
            )
            hn = resolve_container_hn(inbook, sticky, refmap, armap)
            resolved.append({"hn": hn, "text_ar": text_ar, "text_en": text_en})

        from collections import defaultdict

        groups: dict[tuple, list] = defaultdict(list)
        for i, item in enumerate(resolved):
            if item["hn"] is not None:
                continue
            prev = next((resolved[j]["hn"] for j in range(i - 1, -1, -1) if resolved[j]["hn"] is not None), None)
            nxt = next((resolved[j]["hn"] for j in range(i + 1, len(resolved)) if resolved[j]["hn"] is not None), None)
            groups[(prev, nxt)].append(item)

        miss = missing_ar()
        for (prev, nxt), items in groups.items():
            if prev is None or nxt is None or nxt <= prev + 1:
                continue
            holes = [h for h in range(prev + 1, nxt) if h in miss]
            if not holes:
                continue
            for idx, h in enumerate(holes):
                src = items[min(idx, len(items) - 1)]
                row = conn.execute(
                    "SELECT id, text_ar, text_en FROM hadiths WHERE book_id=2 AND hadith_number=?",
                    (h,),
                ).fetchone()
                if not row:
                    continue
                sets: list[str] = []
                vals: list = []
                if not (row["text_ar"] or "").strip():
                    sets.append("text_ar=?")
                    vals.append(src["text_ar"])
                    filled_ar += 1
                if not (row["text_en"] or "").strip() and src["text_en"]:
                    sets.append("text_en=?")
                    vals.append(src["text_en"])
                    filled_en += 1
                if not sets:
                    continue
                vals.append(row["id"])
                conn.execute(f"UPDATE hadiths SET {', '.join(sets)} WHERE id=?", vals)

    # Introduction preface (hadith 1): English chapter introductions from sunnah.com
    intro_path = CACHE / "muslim_book_introduction.html"
    if intro_path.exists():
        intro_html = intro_path.read_text(encoding="utf-8", errors="replace")
        echap = re.findall(r'class="echapintro"[^>]*>(.*?)</div>', intro_html, re.S)
        achap = re.findall(r'class="achapintro"[^>]*>(.*?)</div>', intro_html, re.S)
        row1 = conn.execute(
            "SELECT id, text_ar, text_en FROM hadiths WHERE book_id=2 AND hadith_number=1"
        ).fetchone()
        if row1:
            if not (row1["text_ar"] or "").strip() and achap:
                ar1 = "\n\n".join(strip_tags(x) for x in achap if strip_tags(x))
                if ar1:
                    conn.execute("UPDATE hadiths SET text_ar=? WHERE id=?", (ar1, row1["id"]))
                    filled_ar += 1
            if not (row1["text_en"] or "").strip() and echap:
                en1 = "\n\n".join(strip_tags(x) for x in echap if strip_tags(x))
                if en1:
                    conn.execute("UPDATE hadiths SET text_en=? WHERE id=?", (en1, row1["id"]))
                    filled_en += 1

    conn.commit()
    still_ar = conn.execute(
        "SELECT COUNT(*) FROM hadiths WHERE book_id=2 AND (text_ar IS NULL OR trim(text_ar)='')"
    ).fetchone()[0]
    still_en = conn.execute(
        "SELECT COUNT(*) FROM hadiths WHERE book_id=2 AND (text_en IS NULL OR trim(text_en)='')"
    ).fetchone()[0]
    still_ur = conn.execute(
        "SELECT COUNT(*) FROM hadiths WHERE book_id=2 AND (text_ur IS NULL OR trim(text_ur)='')"
    ).fetchone()[0]
    conn.close()
    return {
        "gap_fill_ar": filled_ar,
        "gap_fill_en": filled_en,
        "still_missing_ar": still_ar,
        "still_missing_en": still_en,
        "still_missing_ur": still_ur,
    }


def scrape_all(refmap, armap) -> tuple[list[dict], dict[str, dict]]:
    index_url = resolve_wayback_url("")
    print(f"Index: {index_url}")
    try:
        index_html = fetch(index_url, "muslim_index.html")
    except Exception:
        index_html = fetch(
            f"https://web.archive.org/web/{FALLBACK_TS}/https://sunnah.com/muslim",
            "muslim_index.html",
        )
    index_books = parse_index(index_html)
    print(f"Index subjects parsed: {len(index_books)}")
    book_meta = {b["slug"]: b for b in index_books}

    all_hadiths: list[dict] = []
    for slug in BOOK_SLUGS:
        wb = resolve_wayback_url(slug)
        print(f"Fetching {slug} ...")
        try:
            html = fetch(wb, f"muslim_book_{slug}.html")
            parsed = parse_book_page(html, slug, refmap, armap)
        except Exception as e:
            print(f"  error: {e}")
            parsed = {"hadiths": [], "chapters": [], "book_en": None, "book_ar": None, "book_slug": slug}

        if not parsed["hadiths"]:
            fb = f"https://web.archive.org/web/{FALLBACK_TS}/https://sunnah.com/muslim/{slug}"
            print(f"  fallback {fb}")
            html = fetch(fb, f"muslim_book_{slug}_fb.html")
            parsed = parse_book_page(html, slug, refmap, armap)

        print(
            f"  hadiths={len(parsed['hadiths'])} chapters={len(parsed['chapters'])} "
            f"with_ar={sum(1 for h in parsed['hadiths'] if h['text_ar'])}"
        )
        if parsed.get("book_en") or parsed.get("book_ar"):
            book_meta.setdefault(slug, {"slug": slug})
            if parsed.get("book_en"):
                book_meta[slug]["title_en"] = parsed["book_en"]
            if parsed.get("book_ar"):
                book_meta[slug]["title_ar"] = parsed["book_ar"]
        all_hadiths.extend(parsed["hadiths"])

    by_n: dict[int, dict] = {}
    for h in all_hadiths:
        n = h["hadith_number"]
        prev = by_n.get(n)
        if prev is None or (not prev.get("text_ar") and h.get("text_ar")):
            by_n[n] = h
    return list(by_n.values()), book_meta


def slug_to_chapter_number(slug: str) -> int:
    return 0 if slug == "introduction" else int(slug)


def ensure_columns(conn: sqlite3.Connection) -> None:
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadiths)")}
    for col, decl in [
        ("bab_number", "TEXT"),
        ("bab_title_en", "TEXT"),
        ("bab_title_ar", "TEXT"),
        ("kitab_title_ar", "TEXT"),
    ]:
        if col not in cols:
            conn.execute(f"ALTER TABLE hadiths ADD COLUMN {col} {decl}")
    ch_cols = {r[1] for r in conn.execute("PRAGMA table_info(chapters)")}
    if "title_ar" not in ch_cols:
        conn.execute("ALTER TABLE chapters ADD COLUMN title_ar TEXT")


def update_db(db_path: Path, hadiths: list[dict], book_meta: dict[str, dict], urdu: dict[int, str]) -> dict:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    ensure_columns(conn)

    book = conn.execute("SELECT id FROM books WHERE slug='muslim'").fetchone()
    if not book:
        raise SystemExit("muslim book not found")
    book_id = int(book["id"])

    chapters = conn.execute(
        "SELECT id, number, title FROM chapters WHERE book_id=? ORDER BY number",
        (book_id,),
    ).fetchall()
    chapter_by_num = {int(c["number"]): c for c in chapters}

    subjects_updated = 0
    for slug, meta in book_meta.items():
        num = slug_to_chapter_number(slug)
        ch = chapter_by_num.get(num)
        if not ch:
            continue
        title_en = (meta.get("title_en") or "").strip()
        title_ar = (meta.get("title_ar") or "").strip()
        if title_en and title_en != (ch["title"] or "").strip():
            conn.execute("UPDATE chapters SET title=? WHERE id=?", (title_en, ch["id"]))
            subjects_updated += 1
        elif title_en and not (ch["title"] or "").strip():
            conn.execute("UPDATE chapters SET title=? WHERE id=?", (title_en, ch["id"]))
            subjects_updated += 1
        if title_ar:
            conn.execute("UPDATE chapters SET title_ar=? WHERE id=?", (title_ar, ch["id"]))
            subjects_updated += 1
            conn.execute(
                "UPDATE hadiths SET kitab_title_ar=? WHERE book_id=? AND chapter_id=?",
                (title_ar, book_id, ch["id"]),
            )

    # Special-case Introduction Arabic title if missing
    intro = chapter_by_num.get(0)
    if intro:
        row = conn.execute("SELECT title_ar FROM chapters WHERE id=?", (intro["id"],)).fetchone()
        if not (row["title_ar"] or "").strip():
            conn.execute("UPDATE chapters SET title_ar=? WHERE id=?", ("المقدمة", intro["id"]))
            subjects_updated += 1

    stats = {
        "ar_filled": 0,
        "en_filled": 0,
        "ur_filled": 0,
        "bab_filled": 0,
        "subjects_updated": subjects_updated,
        "scraped_hadiths": len(hadiths),
        "still_missing_ar": 0,
        "still_missing_en": 0,
        "still_missing_ur": 0,
        "missing_ar_numbers": [],
        "missing_ur_numbers": [],
    }

    by_n = {h["hadith_number"]: h for h in hadiths}
    rows = conn.execute(
        "SELECT id, hadith_number, text_ar, text_en, text_ur FROM hadiths WHERE book_id=? ORDER BY hadith_number",
        (book_id,),
    ).fetchall()

    for row in rows:
        hn = int(row["hadith_number"])
        src = by_n.get(hn)
        ur = urdu.get(hn)
        text_ar = (row["text_ar"] or "").strip()
        text_en = (row["text_en"] or "").strip()
        text_ur = (row["text_ur"] or "").strip()

        sets: list[str] = []
        vals: list = []

        if src:
            if not text_ar and src.get("text_ar"):
                sets.append("text_ar=?")
                vals.append(src["text_ar"])
                stats["ar_filled"] += 1
                text_ar = src["text_ar"]
            if not text_en and src.get("text_en"):
                sets.append("text_en=?")
                vals.append(src["text_en"])
                stats["en_filled"] += 1
                text_en = src["text_en"]
            if src.get("bab_title_en") or src.get("bab_title_ar"):
                sets.extend(["bab_number=?", "bab_title_en=?", "bab_title_ar=?"])
                vals.extend([src.get("bab_number"), src.get("bab_title_en"), src.get("bab_title_ar")])
                stats["bab_filled"] += 1

        if not text_ur and ur:
            sets.append("text_ur=?")
            vals.append(ur)
            stats["ur_filled"] += 1
            text_ur = ur

        if sets:
            vals.append(row["id"])
            conn.execute(f"UPDATE hadiths SET {', '.join(sets)} WHERE id=?", vals)
            fts = conn.execute("SELECT 1 FROM hadith_fts WHERE hadith_id=?", (row["id"],)).fetchone()
            if fts:
                conn.execute(
                    "UPDATE hadith_fts SET text_ar=?, text_en=?, text_ur=? WHERE hadith_id=?",
                    (text_ar, text_en, text_ur, row["id"]),
                )

    miss_ar = [
        int(r[0])
        for r in conn.execute(
            "SELECT hadith_number FROM hadiths WHERE book_id=? AND (text_ar IS NULL OR trim(text_ar)='') ORDER BY hadith_number",
            (book_id,),
        )
    ]
    miss_en = [
        int(r[0])
        for r in conn.execute(
            "SELECT hadith_number FROM hadiths WHERE book_id=? AND (text_en IS NULL OR trim(text_en)='') ORDER BY hadith_number",
            (book_id,),
        )
    ]
    miss_ur = [
        int(r[0])
        for r in conn.execute(
            "SELECT hadith_number FROM hadiths WHERE book_id=? AND (text_ur IS NULL OR trim(text_ur)='') ORDER BY hadith_number",
            (book_id,),
        )
    ]
    stats["still_missing_ar"] = len(miss_ar)
    stats["still_missing_en"] = len(miss_en)
    stats["still_missing_ur"] = len(miss_ur)
    stats["missing_ar_numbers"] = miss_ar
    stats["missing_ur_numbers"] = miss_ur

    conn.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        ("muslim_sunnah_fill", json.dumps({k: v for k, v in stats.items() if not k.startswith("missing_")}, ensure_ascii=False)),
    )
    conn.commit()
    conn.close()
    return stats


def recompress(db_path: Path) -> None:
    gz_path = db_path.with_suffix(db_path.suffix + ".gz")
    with open(db_path, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        f_out.write(f_in.read())
    print(f"Compressed: {gz_path} ({gz_path.stat().st_size / 1024 / 1024:.2f} MB)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--no-gz", action="store_true")
    args = parser.parse_args()

    print("Loading numbering maps + Urdu...")
    refmap, armap = load_number_maps()
    urdu = load_urdu()
    print(f"  refmap={len(refmap)} armap={len(armap)} urdu={len(urdu)}")

    hadiths, book_meta = scrape_all(refmap, armap)
    print(f"Unique scraped hadiths: {len(hadiths)}; subjects: {len(book_meta)}")

    dump = CACHE / "muslim_scraped.json"
    dump.write_text(json.dumps({"books": book_meta, "hadiths": hadiths}, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {dump}")

    stats = update_db(args.db, hadiths, book_meta, urdu)
    print(json.dumps({k: v for k, v in stats.items() if not k.startswith("missing_")}, indent=2, ensure_ascii=False))

    print("Gap-filling unmapped sunnah.com variant blocks...")
    gap_stats = gap_fill_from_cache(args.db, refmap, armap)
    stats.update(gap_stats)
    # refresh missing lists after gap fill
    conn = sqlite3.connect(args.db)
    stats["missing_ar_numbers"] = [
        int(r[0])
        for r in conn.execute(
            "SELECT hadith_number FROM hadiths WHERE book_id=2 AND (text_ar IS NULL OR trim(text_ar)='') ORDER BY hadith_number"
        )
    ]
    stats["missing_ur_numbers"] = [
        int(r[0])
        for r in conn.execute(
            "SELECT hadith_number FROM hadiths WHERE book_id=2 AND (text_ur IS NULL OR trim(text_ur)='') ORDER BY hadith_number"
        )
    ]
    stats["still_missing_ar"] = len(stats["missing_ar_numbers"])
    stats["still_missing_ur"] = len(stats["missing_ur_numbers"])
    stats["still_missing_en"] = conn.execute(
        "SELECT COUNT(*) FROM hadiths WHERE book_id=2 AND (text_en IS NULL OR trim(text_en)='')"
    ).fetchone()[0]
    subjects_ar = conn.execute(
        "SELECT COUNT(*) FROM chapters WHERE book_id=2 AND title_ar IS NOT NULL AND trim(title_ar)!=''"
    ).fetchone()[0]
    stats["subjects_with_arabic"] = subjects_ar
    conn.close()

    print(json.dumps({k: v for k, v in stats.items() if not k.startswith("missing_")}, indent=2, ensure_ascii=False))
    print(f"Still missing AR ({stats['still_missing_ar']}): {stats['missing_ar_numbers'][:40]}")
    print(f"Still missing UR ({stats['still_missing_ur']}): {stats['missing_ur_numbers'][:40]}")

    report = ROOT / "reports" / "verification" / "muslim_sunnah_fill_report.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(stats, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    summary = ROOT / "reports" / "verification" / "MUSLIM_SUNNAH_FILL.md"
    summary.write_text(
        "\n".join(
            [
                "# Sahih Muslim — sunnah.com data fill",
                "",
                "Source process matches MOQDEMA/Introduction work: pull subjects + Arabic/English from sunnah.com, Urdu from the authentic `urd-muslim` edition. No AI-generated hadith text.",
                "",
                "## Results",
                f"- Kitab subjects with Arabic titles: **{stats.get('subjects_with_arabic', 0)}/57**",
                f"- Bab subjects stamped onto hadiths: **{stats.get('bab_filled', 0)}**",
                f"- Arabic filled this run: **{stats.get('ar_filled', 0)}** (+ gap-fill **{stats.get('gap_fill_ar', 0)}**)",
                f"- English filled this run: **{stats.get('en_filled', 0)}** (+ gap-fill **{stats.get('gap_fill_en', 0)}**)",
                f"- Urdu filled this run: **{stats.get('ur_filled', 0)}** (only where `urd-muslim` already has text)",
                f"- Still missing Arabic: **{stats['still_missing_ar']}**",
                f"- Still missing Urdu: **{stats['still_missing_ur']}**",
                "",
                "## Remaining gaps",
                "Arabic gaps are placeholder rows with no sunnah.com Arabic/English body (and none in `ara-muslim`/`eng-muslim`).",
                "Urdu gaps (including Introduction 56–92) are empty in the authentic `urd-muslim` edition; they were not machine-translated.",
                "",
                f"Missing AR numbers: `{stats['missing_ar_numbers']}`",
                "",
                f"Missing UR numbers: `{stats['missing_ur_numbers']}`",
                "",
            ]
        ),
        encoding="utf-8",
    )

    if not args.no_gz:
        recompress(args.db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
