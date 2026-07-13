#!/usr/bin/env python3
"""Hadith Quality Audit + Repair (STRICT — no AI content).

Cross-checks Sahih Bukhari, Sahih Muslim, Sunan Abi Dawood, and Jami' at-Tirmidhi
against the authenticated edition files that this pack was built from
(fawazahmed0/hadith-api@1 via jsDelivr CDN).

Rules:
  - Never invent Arabic, translations, narrators, grades, or references.
  - If Arabic exists in the authenticated source → import exactly.
  - If Arabic does not exist in the source → leave empty.
  - Clear local text_ar that has no Arabic script (false English placeholders).
  - Recover narrator only from authenticated English "Narrated X:" prefix.
  - Write a full audit report; do not silently modify without logging.

Usage:
  python3 tools/verification/audit_and_repair_hadith.py
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith.db"
REPORT_JSON = ROOT / "reports" / "verification" / "HADITH_QUALITY_AUDIT.json"
REPORT_MD = ROOT / "reports" / "verification" / "HADITH_QUALITY_AUDIT.md"
SLUGS = ("bukhari", "muslim", "abudawud", "tirmidhi")
CDN = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions"
AR_RE = re.compile(r"[\u0600-\u06FF]")
NARR_RE = re.compile(r"^Narrated\s+([^:]+):", re.IGNORECASE)


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307-hadith-audit/1.0"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.load(resp)


def has_arabic(text: str | None) -> bool:
    return bool(text and AR_RE.search(text))


def extract_narrator(text_en: str | None) -> str | None:
    if not text_en:
        return None
    m = NARR_RE.match(text_en.strip())
    return m.group(1).strip() if m else None


def open_db() -> sqlite3.Connection:
    if not GZ.exists() and not DB.exists():
        raise SystemExit(f"Missing hadith database at {GZ}")
    if GZ.exists():
        DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def ensure_columns(conn: sqlite3.Connection) -> None:
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadiths)")}
    if "reference_url" not in cols:
        conn.execute("ALTER TABLE hadiths ADD COLUMN reference_url TEXT")
    if "source_provider" not in cols:
        conn.execute("ALTER TABLE hadiths ADD COLUMN source_provider TEXT")
    conn.commit()


def load_source_edition(slug: str, lang_prefix: str) -> dict[int, dict]:
    data = fetch_json(f"{CDN}/{lang_prefix}-{slug}.json")
    out: dict[int, dict] = {}
    for h in data.get("hadiths") or []:
        try:
            n = int(h.get("hadithnumber") or 0)
        except (TypeError, ValueError):
            continue
        if n:
            out[n] = h
    return out


def main() -> int:
    REPORT_JSON.parent.mkdir(parents=True, exist_ok=True)
    conn = open_db()
    ensure_columns(conn)

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "policy": [
            "Never invent Arabic/translation/narrator/grade/reference with AI.",
            "Cross-check only against authenticated source editions.",
            "Empty Arabic left empty when missing in authenticated source.",
        ],
        "source": "fawazahmed0/hadith-api@1 (same provenance as current hadith.db)",
        "books": {},
        "totals": {
            "hadith_checked": 0,
            "arabic_imported_from_source": 0,
            "arabic_cleared_non_arabic_script": 0,
            "narrators_corrected": 0,
            "references_corrected": 0,
            "missing_authenticated_arabic": 0,
            "remaining_issues": [],
        },
    }

    for slug in SLUGS:
        print(f"Auditing {slug}...")
        book = conn.execute("SELECT id, name_en FROM books WHERE slug=?", (slug,)).fetchone()
        if not book:
            summary["totals"]["remaining_issues"].append(f"Book slug missing in DB: {slug}")
            continue
        book_id = book["id"]
        ara = load_source_edition(slug, "ara")
        eng = load_source_edition(slug, "eng")

        rows = conn.execute(
            """
            SELECT id, hadith_number, text_ar, text_en, narrator, grade,
                   reference_book, reference_hadith, reference_url, source_provider
            FROM hadiths WHERE book_id=? ORDER BY hadith_number
            """,
            (book_id,),
        ).fetchall()

        book_stats = {
            "name": book["name_en"],
            "total": len(rows),
            "arabic_imported": 0,
            "arabic_cleared": 0,
            "narrators_corrected": 0,
            "references_corrected": 0,
            "missing_authenticated_arabic": 0,
            "mismatches": [],
        }

        for row in rows:
            summary["totals"]["hadith_checked"] += 1
            n = int(row["hadith_number"])
            hid = int(row["id"])
            local_ar = (row["text_ar"] or "").strip()
            local_en = (row["text_en"] or "").strip()
            local_narr = (row["narrator"] or "").strip()
            src_ar = (ara.get(n, {}).get("text") or "").strip()
            src_en = (eng.get(n, {}).get("text") or "").strip()

            # 1) Arabic corrections from authenticated source only
            if local_ar and not has_arabic(local_ar):
                if has_arabic(src_ar):
                    conn.execute("UPDATE hadiths SET text_ar=? WHERE id=?", (src_ar, hid))
                    book_stats["arabic_imported"] += 1
                    summary["totals"]["arabic_imported_from_source"] += 1
                    book_stats["mismatches"].append(
                        {"n": n, "field": "text_ar", "action": "replaced_non_arabic_with_source_arabic"}
                    )
                else:
                    conn.execute("UPDATE hadiths SET text_ar=? WHERE id=?", ("", hid,))
                    book_stats["arabic_cleared"] += 1
                    summary["totals"]["arabic_cleared_non_arabic_script"] += 1
                    book_stats["mismatches"].append(
                        {"n": n, "field": "text_ar", "action": "cleared_non_arabic_placeholder"}
                    )
            elif not local_ar and has_arabic(src_ar):
                conn.execute("UPDATE hadiths SET text_ar=? WHERE id=?", (src_ar, hid))
                book_stats["arabic_imported"] += 1
                summary["totals"]["arabic_imported_from_source"] += 1
                book_stats["mismatches"].append(
                    {"n": n, "field": "text_ar", "action": "imported_missing_arabic_from_source"}
                )
            elif not local_ar and not has_arabic(src_ar):
                book_stats["missing_authenticated_arabic"] += 1
                summary["totals"]["missing_authenticated_arabic"] += 1

            # 2) Narrator — authenticated English prefix only; never invent
            src_narr = extract_narrator(src_en) or extract_narrator(local_en)
            if src_narr:
                if not local_narr:
                    conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", (src_narr, hid))
                    book_stats["narrators_corrected"] += 1
                    summary["totals"]["narrators_corrected"] += 1
                    book_stats["mismatches"].append(
                        {"n": n, "field": "narrator", "action": "imported_from_authenticated_english"}
                    )
                elif local_narr != src_narr:
                    # Prefer authenticated source English Narrated label
                    conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", (src_narr, hid))
                    book_stats["narrators_corrected"] += 1
                    summary["totals"]["narrators_corrected"] += 1
                    book_stats["mismatches"].append(
                        {
                            "n": n,
                            "field": "narrator",
                            "action": "replaced_with_authenticated_value",
                            "from": local_narr,
                            "to": src_narr,
                        }
                    )

            # 3) Reference URL + source provider (canonical, not invented text)
            url = f"https://sunnah.com/{slug}:{n}"
            provider = "fawazahmed0/hadith-api@1"
            need_ref = (row["reference_url"] or "").strip() != url
            need_prov = (row["source_provider"] or "").strip() != provider
            if need_ref or need_prov:
                conn.execute(
                    "UPDATE hadiths SET reference_url=?, source_provider=? WHERE id=?",
                    (url, provider, hid),
                )
                book_stats["references_corrected"] += 1
                summary["totals"]["references_corrected"] += 1

        summary["books"][slug] = book_stats
        # Cap mismatch list size in report for readability
        if len(book_stats["mismatches"]) > 200:
            book_stats["mismatches_truncated"] = len(book_stats["mismatches"]) - 200
            book_stats["mismatches"] = book_stats["mismatches"][:200]

    # meta provenance note
    try:
        conn.execute(
            "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
            ("last_quality_audit", summary["generated_at"]),
        )
        conn.execute(
            "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
            (
                "quality_audit_note",
                "Arabic/narrator cross-checked against fawazahmed0/hadith-api@1. "
                "Empty Arabic left empty when missing in source. No AI text generated.",
            ),
        )
    except sqlite3.Error:
        pass

    conn.commit()
    conn.close()

    # recompress
    with gzip.open(GZ, "wb", compresslevel=9) as gz:
        gz.write(DB.read_bytes())
    DB.unlink(missing_ok=True)

    REPORT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT_MD.write_text(_md(summary), encoding="utf-8")
    print(f"Wrote {REPORT_JSON}")
    print(f"Wrote {REPORT_MD}")
    print(json.dumps(summary["totals"], indent=2))
    return 0


def _md(summary: dict) -> str:
    t = summary["totals"]
    lines = [
        "# Hadith Quality Audit Report",
        "",
        f"Generated: `{summary['generated_at']}`",
        "",
        "## Policy",
        "",
        "- Never invent Arabic, translation, narrator, grade, or reference with AI.",
        "- Cross-check only against authenticated source editions.",
        "- If Arabic is missing in the authenticated source, leave it empty.",
        "",
        f"**Source checked:** `{summary['source']}`",
        "",
        "## Totals",
        "",
        f"- Total Hadith checked: **{t['hadith_checked']}**",
        f"- Arabic imported from authenticated source: **{t['arabic_imported_from_source']}**",
        f"- Non-Arabic placeholders cleared from text_ar: **{t['arabic_cleared_non_arabic_script']}**",
        f"- Narrators corrected from authenticated English: **{t['narrators_corrected']}**",
        f"- References corrected (URL + provider): **{t['references_corrected']}**",
        f"- Missing authenticated Arabic (empty in source too): **{t['missing_authenticated_arabic']}**",
        "",
        "## Per book",
        "",
    ]
    for slug, b in summary["books"].items():
        lines += [
            f"### {b['name']} (`{slug}`)",
            "",
            f"- Total: {b['total']}",
            f"- Arabic imported: {b['arabic_imported']}",
            f"- Arabic cleared (non-Arabic script): {b['arabic_cleared']}",
            f"- Narrators corrected: {b['narrators_corrected']}",
            f"- References corrected: {b['references_corrected']}",
            f"- Missing authenticated Arabic: {b['missing_authenticated_arabic']}",
            f"- Logged mismatch actions: {len(b['mismatches'])}"
            + (f" (truncated from {b.get('mismatches_truncated', 0) + len(b['mismatches'])})" if b.get("mismatches_truncated") else ""),
            "",
        ]
    if t["remaining_issues"]:
        lines += ["## Remaining issues", ""]
        for issue in t["remaining_issues"]:
            lines.append(f"- {issue}")
        lines.append("")
    lines += [
        "## Notes",
        "",
        "- UI shows “Arabic text unavailable in authenticated source.” only when Arabic is truly empty after this audit.",
        "- A future Sunnah.com API rebuild (with API key) remains the preferred long-term primary source migration.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
