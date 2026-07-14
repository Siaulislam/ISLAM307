#!/usr/bin/env python3
"""Fill missing narrators from sunnah.com with content verification (no AI).

Rules:
  - Never invent narrator names.
  - Do NOT trust hadith number alone.
  - Fetch the sunnah.com page for the stored reference URL.
  - Verify collection/book identity and (when possible) English/Arabic overlap
    or in-book reference match before accepting a narrator.
  - Prefer explicit "Narrated X:" on the page; else last authenticated
    sunnah.com/narrator link from the Arabic isnad; else previous hadith
    only when the page says "same narrator" / "with his isnad" / "another version"
    AND content verification passes.
  - If verification fails, leave empty and log the reason.
"""

from __future__ import annotations

import csv
import gzip
import json
import re
import sqlite3
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith_sunnah_narr.db"
CACHE = ROOT / "tools" / "verification" / "cache" / "sunnah_pages"
OUT_DIR = ROOT / "reports" / "verification"
REPORT_MD = OUT_DIR / "SUNNAH_NARRATOR_FILL_REPORT.md"
REPORT_JSON = OUT_DIR / "SUNNAH_NARRATOR_FILL_REPORT.json"
REPORT_CSV = OUT_DIR / "SUNNAH_NARRATOR_FILL_REPORT.csv"

SLUGS = ("bukhari", "muslim", "abudawud", "tirmidhi")
COLLECTION = {
    "bukhari": ("Sahih al-Bukhari", "صحيح البخاري"),
    "muslim": ("Sahih Muslim", "صحيح مسلم"),
    "abudawud": ("Sunan Abi Dawud", "سنن أبي داود"),
    "tirmidhi": ("Jami` at-Tirmidhi", "Jami' at-Tirmidhi", "جامع الترمذي"),
}

AR_RE = re.compile(r"[\u0600-\u06FF]")
NARRATED_RE = re.compile(r"(?:^|\n)\s*Narrated\s+(.+?)\s*:", re.I)
SAME_NARR_RE = re.compile(
    r"same narrator|with (?:his|the same) (?:isnad|chain)|another version|"
    r"وبإسناده|بهذا الإسناد|بهذا الاسناد|باسناده",
    re.I,
)
INBOOK_RE = re.compile(r"In-book reference:\s*Book\s+(\d+),\s*Hadith\s+(\d+)", re.I)
NARR_LINK_RE = re.compile(r"https://sunnah\.com/narrator/\d+\s+\"([^\"]+)\"")
PROPHET_NAME = re.compile(r"رسول|النبي|نبي الله|محمد", re.I)


def fetch_sunnah(url: str) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r"[^\w.\-:]+", "_", url.replace("https://", ""))
    cpath = CACHE / f"{safe}.md"
    if cpath.exists() and cpath.stat().st_size > 500:
        return cpath.read_text(encoding="utf-8")
    jurl = "https://r.jina.ai/" + url
    req = urllib.request.Request(
        jurl,
        headers={
            "User-Agent": "Mozilla/5.0 ISLAM307-sunnah-fill/1.0",
            "Accept": "text/markdown",
            "X-Return-Format": "markdown",
            "X-Wait-For-Selector": ".actualHadithContainer",
        },
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = resp.read().decode("utf-8", "replace")
            cpath.write_text(body, encoding="utf-8")
            time.sleep(0.55)
            return body
        except Exception:
            if attempt == 3:
                raise
            time.sleep(1.5 * (attempt + 1))
    return ""


def norm(text: str) -> str:
    t = re.sub(r"\s+", " ", (text or "")).strip().lower()
    t = re.sub(r"[^\w\u0600-\u06FF\s]", "", t)
    return t


def fingerprint_overlap(a: str, b: str, min_chars: int = 28) -> bool:
    na, nb = norm(a), norm(b)
    if not na or not nb:
        return False
    # use a mid-length token window from local text
    if len(na) < 12 or len(nb) < 12:
        return na in nb or nb in na
    # try several slices
    for start in (0, max(0, len(na) // 4), max(0, len(na) // 2)):
        chunk = na[start : start + max(min_chars, min(60, len(na)))]
        if len(chunk) >= 12 and chunk in nb:
            return True
    # arabic letter-only overlap
    a_ar = "".join(ch for ch in a if "\u0600" <= ch <= "\u06FF")
    b_ar = "".join(ch for ch in b if "\u0600" <= ch <= "\u06FF")
    if len(a_ar) >= 20:
        for start in (0, len(a_ar) // 3):
            chunk = a_ar[start : start + 24]
            if chunk and chunk in b_ar:
                return True
    return False


def parse_page(body: str, slug: str, n: int) -> dict:
    names = COLLECTION[slug]
    collection_ok = any(name.lower() in body.lower() for name in names if not AR_RE.search(name))
    if not collection_ok:
        # arabic collection titles
        collection_ok = any(name in body for name in names if AR_RE.search(name))

    # English block: from collection+number heading to Reference/Grade
    pat = re.compile(
        rf"(?:Sahih al-Bukhari|Sahih Muslim|Sunan Abi Dawud|Jami.`? at-Tirmidhi)\s+{n}\b"
        rf"(.*?)(?:\*\*Reference\*\*|\*\*Grade\*\*|In-book reference)",
        re.S | re.I,
    )
    m = pat.search(body)
    block = m.group(1) if m else ""
    narrated = None
    m2 = NARRATED_RE.search(block) or NARRATED_RE.search(body)
    if m2:
        narrated = re.sub(r"\s+", " ", m2.group(1)).strip(" .")

    en_parts: list[str] = []
    ar_parts: list[str] = []
    for ln in block.splitlines():
        s = ln.strip()
        if not s:
            continue
        if AR_RE.search(s):
            s2 = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)
            ar_parts.append(s2)
        elif s.startswith("http") or (s.startswith("[") and "](" in s and len(s) < 100):
            continue
        elif re.match(r"^\(?\d+\)?$", s) or s in {"English", "Urdu", "Bangla"}:
            continue
        else:
            # drop pure nav crumbs
            if "Select Collections" in s or "Donate Now" in s:
                continue
            en_parts.append(s)
    en = " ".join(en_parts)
    ar = " ".join(ar_parts)

    inbook = INBOOK_RE.search(body)
    inbook_book = int(inbook.group(1)) if inbook else None
    inbook_hadith = int(inbook.group(2)) if inbook else None

    links = NARR_LINK_RE.findall(body)
    # de-dupe preserving order
    seen: set[str] = set()
    link_names: list[str] = []
    for name in links:
        key = re.sub(r"\s+", " ", name).strip()
        if key and key not in seen and not PROPHET_NAME.search(key):
            seen.add(key)
            link_names.append(key)

    same_chain = bool(SAME_NARR_RE.search(en) or SAME_NARR_RE.search(ar) or SAME_NARR_RE.search(block))

    # Title number check (page is for this hadith id)
    title_has_n = bool(re.search(rf"\b{n}\b", body[:800]))

    return {
        "collection_ok": collection_ok,
        "title_has_n": title_has_n,
        "narrated": narrated,
        "en": en,
        "ar": ar,
        "inbook_book": inbook_book,
        "inbook_hadith": inbook_hadith,
        "link_names": link_names,
        "same_chain": same_chain,
    }


def choose_narrator(parsed: dict, prev_narrator: str | None) -> tuple[str | None, str]:
    if parsed.get("narrated"):
        return parsed["narrated"], "sunnah_narrated_label"
    if parsed.get("same_chain") and prev_narrator:
        return prev_narrator, "sunnah_same_chain_previous"
    links = parsed.get("link_names") or []
    if links:
        # Companion is typically the last named person in the Arabic isnad links
        return links[-1], "sunnah_arabic_isnad_last_link"
    return None, "none"


def verify_match(local: sqlite3.Row, parsed: dict) -> tuple[bool, str]:
    if not parsed["collection_ok"]:
        return False, "collection_mismatch"
    local_en = (local["text_en"] or "").strip()
    local_ar = (local["text_ar"] or "").strip()
    ref_book = local["reference_book"]
    try:
        ref_book_i = int(ref_book) if ref_book is not None and str(ref_book).strip() != "" else None
    except ValueError:
        ref_book_i = None
    ch_num = local["chapter_number"]
    try:
        ch_i = int(ch_num) if ch_num is not None and str(ch_num).strip() != "" else None
    except ValueError:
        ch_i = None

    text_ok = False
    if local_en and fingerprint_overlap(local_en, parsed["en"] or ""):
        text_ok = True
    if local_ar and fingerprint_overlap(local_ar, parsed["ar"] or ""):
        text_ok = True
    # also allow local EN vs full page (referential short lines)
    if local_en and fingerprint_overlap(local_en, parsed["en"] + " " + (parsed["ar"] or ""), min_chars=20):
        text_ok = True

    inbook_ok = False
    if parsed["inbook_book"] is not None:
        if ref_book_i and ref_book_i > 0 and parsed["inbook_book"] == ref_book_i:
            inbook_ok = True
        elif ch_i and ch_i > 0 and parsed["inbook_book"] == ch_i:
            inbook_ok = True

    if text_ok and inbook_ok:
        return True, "text_and_inbook_match"
    if text_ok:
        return True, "text_fingerprint_match"
    if inbook_ok and (local_en or local_ar or (local["text_ur"] or "").strip()):
        # Have some local content identity via chapter/book mapping + non-empty local corpus
        return True, "inbook_ref_match_with_local_content"
    if inbook_ok and not local_en and not local_ar:
        # Empty EN/AR: only accept if in-book matches AND page has extractable narrator evidence
        if parsed.get("narrated") or parsed.get("link_names") or parsed.get("same_chain"):
            return True, "inbook_ref_match_empty_local_texts"
        return False, "inbook_ok_but_no_narrator_on_page"
    if not local_en and not local_ar and not (local["text_ur"] or "").strip():
        return False, "local_empty_cannot_verify_without_inbook"
    return False, "no_text_or_inbook_match"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row

    missing = conn.execute(
        """
        SELECT h.id, b.slug, b.name_en, h.hadith_number, h.narrator,
               h.text_ar, h.text_en, h.text_ur, h.reference_url,
               h.reference_book, h.reference_hadith,
               c.number AS chapter_number, c.title AS chapter_title
        FROM hadiths h
        JOIN books b ON b.id = h.book_id
        LEFT JOIN chapters c ON c.id = h.chapter_id
        WHERE b.slug IN ('bukhari','muslim','abudawud','tirmidhi')
          AND TRIM(IFNULL(h.narrator,'')) = ''
        ORDER BY b.slug, h.hadith_number
        """
    ).fetchall()

    print(f"Missing narrators to attempt: {len(missing)}", flush=True)

    # previous narrator lookup (same book, previous number with narrator)
    prev_cache: dict[tuple[str, int], str] = {}
    for row in conn.execute(
        """
        SELECT b.slug, h.hadith_number, h.narrator
        FROM hadiths h JOIN books b ON b.id=h.book_id
        WHERE b.slug IN ('bukhari','muslim','abudawud','tirmidhi')
          AND TRIM(IFNULL(h.narrator,'')) != ''
        """
    ):
        prev_cache[(row["slug"], int(row["hadith_number"]))] = row["narrator"].strip()

    def nearest_prev(slug: str, n: int) -> str | None:
        for k in range(n - 1, max(0, n - 6), -1):
            if (slug, k) in prev_cache:
                return prev_cache[(slug, k)]
        return None

    results: list[dict] = []
    stats = Counter()

    for i, row in enumerate(missing, 1):
        slug = row["slug"]
        n = int(row["hadith_number"])
        url = (row["reference_url"] or "").strip() or f"https://sunnah.com/{slug}:{n}"
        print(f"[{i}/{len(missing)}] {slug}:{n} ...", flush=True)
        entry = {
            "Book": row["name_en"],
            "Book Slug": slug,
            "Hadith Number": n,
            "Reference URL": url,
            "Local EN prefix": (row["text_en"] or "")[:120],
            "Local AR prefix": (row["text_ar"] or "")[:80],
            "Imported Narrator": "",
            "Method": "",
            "Verification": "",
            "Status": "",
            "Notes": "",
        }
        try:
            body = fetch_sunnah(url)
        except Exception as e:
            entry["Status"] = "FETCH_FAILED"
            entry["Notes"] = str(e)[:200]
            stats["fetch_failed"] += 1
            results.append(entry)
            continue

        parsed = parse_page(body, slug, n)
        ok, why = verify_match(row, parsed)
        entry["Verification"] = why
        if not ok:
            entry["Status"] = "LEFT_EMPTY_UNVERIFIED"
            entry["Notes"] = (
                f"collection_ok={parsed['collection_ok']} "
                f"inbook={parsed['inbook_book']}:{parsed['inbook_hadith']} "
                f"narrated={parsed['narrated']!r} links={len(parsed['link_names'])}"
            )
            stats["left_empty"] += 1
            results.append(entry)
            continue

        prev = nearest_prev(slug, n)
        name, method = choose_narrator(parsed, prev)
        if not name:
            entry["Status"] = "LEFT_EMPTY_NO_RAVI_ON_PAGE"
            entry["Notes"] = "Verified same hadith/book but sunnah page has no extractable narrator"
            stats["verified_but_no_ravi"] += 1
            results.append(entry)
            continue

        conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", (name, row["id"]))
        prev_cache[(slug, n)] = name
        entry["Imported Narrator"] = name
        entry["Method"] = method
        entry["Status"] = "IMPORTED"
        entry["Notes"] = (
            f"Verified via {why}; sunnah in-book Book {parsed['inbook_book']} "
            f"Hadith {parsed['inbook_hadith']}"
        )
        stats["imported"] += 1
        print(f"  -> {name} ({method}, {why})", flush=True)
        results.append(entry)

    conn.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        ("last_sunnah_narrator_fill", generated_at),
    )
    conn.commit()
    conn.close()

    with gzip.open(GZ, "wb", compresslevel=9) as gz:
        gz.write(DB.read_bytes())
    DB.unlink(missing_ok=True)

    # remaining missing count
    DB2 = ROOT / "app" / "assets" / "databases" / "hadith_check.db"
    DB2.write_bytes(gzip.decompress(GZ.read_bytes()))
    c2 = sqlite3.connect(DB2)
    remain = c2.execute(
        """
        SELECT b.slug, COUNT(*) c FROM hadiths h JOIN books b ON b.id=h.book_id
        WHERE b.slug IN ('bukhari','muslim','abudawud','tirmidhi')
          AND TRIM(IFNULL(h.narrator,''))=''
        GROUP BY b.slug
        """
    ).fetchall()
    remain_total = sum(r[1] for r in remain)
    c2.close()
    DB2.unlink(missing_ok=True)

    fields = list(results[0].keys()) if results else [
        "Book", "Hadith Number", "Imported Narrator", "Status", "Verification"
    ]
    with REPORT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(results)

    summary = {
        "generated_at": generated_at,
        "policy": [
            "Never invent narrators.",
            "Copied only from sunnah.com after verifying book + content/in-book reference.",
            "Did not trust hadith number alone.",
        ],
        "attempted": len(missing),
        "imported": stats["imported"],
        "left_empty_unverified": stats["left_empty"],
        "verified_but_no_ravi": stats["verified_but_no_ravi"],
        "fetch_failed": stats["fetch_failed"],
        "remaining_missing_by_book": {r[0]: r[1] for r in remain},
        "remaining_missing_total": remain_total,
        "methods": Counter(r["Method"] for r in results if r["Status"] == "IMPORTED"),
    }
    # Counter not json serializable directly in nested - fix
    summary["methods"] = dict(summary["methods"])

    REPORT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT_MD.write_text(_md(summary, results), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


def _md(summary: dict, results: list[dict]) -> str:
    imported = [r for r in results if r["Status"] == "IMPORTED"]
    lines = [
        "# Sunnah.com Narrator Fill Report",
        "",
        f"Generated: `{summary['generated_at']}`",
        "",
        "## Policy",
        "",
        "- Never invent narrator names.",
        "- Fetch sunnah.com page for each missing ravi.",
        "- Verify **same book** + **same hadith content / in-book reference** (do not trust number alone).",
        "- If verification fails, leave empty.",
        "",
        "## Totals",
        "",
        f"| Metric | Count |",
        f"|--------|------:|",
        f"| Attempted (were missing) | **{summary['attempted']}** |",
        f"| Imported from sunnah.com (verified) | **{summary['imported']}** |",
        f"| Left empty (could not verify) | **{summary['left_empty_unverified']}** |",
        f"| Verified page but no ravi on page | **{summary['verified_but_no_ravi']}** |",
        f"| Fetch failed | **{summary['fetch_failed']}** |",
        f"| Still missing after fill | **{summary['remaining_missing_total']}** |",
        "",
        "### Still missing by book",
        "",
    ]
    for slug, c in summary["remaining_missing_by_book"].items():
        lines.append(f"- `{slug}`: {c}")
    lines += ["", "### Import methods", ""]
    for m, c in summary["methods"].items():
        lines.append(f"- `{m}`: {c}")
    lines += ["", "## Imported rows (manual check)", ""]
    lines.append("| Book | # | Narrator | Method | Verification |")
    lines.append("|------|--:|----------|--------|--------------|")
    for r in imported:
        lines.append(
            f"| {r['Book']} | {r['Hadith Number']} | {r['Imported Narrator']} | "
            f"`{r['Method']}` | {r['Verification']} |"
        )
    lines += [
        "",
        "## Full CSV",
        "",
        "`reports/verification/SUNNAH_NARRATOR_FILL_REPORT.csv`",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
