#!/usr/bin/env python3
"""Second forensic audit — narrator verification after rebuild (no AI).

Verifies every hadith.narrator against authenticated fawazahmed0/hadith-api@1
English + Arabic editions. Produces exact statistics + CSV for manual review.

Outputs:
  reports/verification/HADITH_FORENSIC_AUDIT_NARRATORS.md
  reports/verification/HADITH_FORENSIC_AUDIT_NARRATORS.json
  reports/verification/HADITH_FORENSIC_AUDIT_NARRATORS.csv
"""

from __future__ import annotations

import csv
import gzip
import json
import sqlite3
import sys
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "verification"))
sys.path.insert(0, str(ROOT / "tools" / "hadith"))

from rebuild_narrators import (  # noqa: E402
    resolve_narrator,
    load_edition,
    SLUGS,
    CDN,
)

GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith_forensic_narr.db"
OUT_DIR = ROOT / "reports" / "verification"
REPORT_MD = OUT_DIR / "HADITH_FORENSIC_AUDIT_NARRATORS.md"
REPORT_JSON = OUT_DIR / "HADITH_FORENSIC_AUDIT_NARRATORS.json"
REPORT_CSV = OUT_DIR / "HADITH_FORENSIC_AUDIT_NARRATORS.csv"


def yes_no(v: bool) -> str:
    return "Yes" if v else "No"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row

    csv_rows: list[dict] = []
    books_out: dict = {}
    totals = Counter()
    reason_totals = Counter()

    for slug in SLUGS:
        print(f"Narrator forensic: {slug} ...", flush=True)
        book = conn.execute("SELECT id, name_en FROM books WHERE slug=?", (slug,)).fetchone()
        if not book:
            continue
        eng = load_edition(slug, "eng")
        ara = load_edition(slug, "ara")
        rows = conn.execute(
            """
            SELECT hadith_number, narrator, text_ar, text_en, text_ur, grade,
                   reference_url, source_provider
            FROM hadiths WHERE book_id=? ORDER BY hadith_number
            """,
            (book["id"],),
        ).fetchall()

        b = {
            "book": book["name_en"],
            "slug": slug,
            "total": len(rows),
            "narrator_present": 0,
            "narrator_absent": 0,
            "verified_match": 0,
            "mismatch": 0,
            "missing_unverifiable": 0,
            "missing_but_source_has": 0,
            "arabic_present": 0,
            "translation_present": 0,
            "reference_present": 0,
            "grade_present": 0,
        }

        for row in rows:
            n = int(row["hadith_number"])
            stored = (row["narrator"] or "").strip()
            src_en = (eng.get(n, {}).get("text") or row["text_en"] or "").strip()
            src_ar = (ara.get(n, {}).get("text") or row["text_ar"] or "").strip()
            expected, method, lang = resolve_narrator(src_en, src_ar)

            narr_present = bool(stored)
            ar_present = bool(row["text_ar"] and any("\u0600" <= c <= "\u06FF" for c in row["text_ar"]))
            tr_present = bool((row["text_en"] or "").strip() or (row["text_ur"] or "").strip())
            ref_present = bool((row["reference_url"] or "").strip() or (row["source_provider"] or "").strip())
            grade = (row["grade"] or "").strip()
            grade_present = bool(grade) and grade != "Grade not verified."

            if narr_present:
                b["narrator_present"] += 1
                totals["narrator_present"] += 1
            else:
                b["narrator_absent"] += 1
                totals["narrator_absent"] += 1

            if ar_present:
                b["arabic_present"] += 1
            if tr_present:
                b["translation_present"] += 1
            if ref_present:
                b["reference_present"] += 1
            if grade_present:
                b["grade_present"] += 1

            # Verification status vs authenticated source re-extraction
            if stored and expected and stored == expected:
                status = "VERIFIED_MATCH"
                reason = ""
                b["verified_match"] += 1
                totals["verified_match"] += 1
            elif stored and expected and stored != expected:
                status = "MISMATCH"
                reason = f"Stored differs from authenticated extraction ({lang}:{method})"
                b["mismatch"] += 1
                totals["mismatch"] += 1
            elif stored and not expected:
                status = "STORED_BUT_SOURCE_UNVERIFIABLE"
                reason = "Stored narrator could not be re-derived from authenticated editions"
                b["mismatch"] += 1
                totals["mismatch"] += 1
            elif not stored and expected:
                status = "MISSING_BUT_SOURCE_HAS"
                reason = f"Authenticated source yields narrator via {lang}:{method} but DB empty"
                b["missing_but_source_has"] += 1
                totals["missing_but_source_has"] += 1
            else:
                status = "MISSING_UNVERIFIABLE"
                reason = "No verifiable narrator in authenticated English or Arabic isnad"
                b["missing_unverifiable"] += 1
                totals["missing_unverifiable"] += 1

            reason_totals[status] += 1
            totals["total"] += 1

            csv_rows.append(
                {
                    "Book": book["name_en"],
                    "Hadith Number": n,
                    "Narrator Present (Yes/No)": yes_no(narr_present),
                    "Narrator Value": stored,
                    "Authenticated Extraction": expected or "",
                    "Extraction Method": f"{lang}:{method}" if method else "",
                    "Verification Status": status,
                    "Reason if Narrator missing/mismatch": reason,
                    "Arabic Present (Yes/No)": yes_no(ar_present),
                    "Translation Present (Yes/No)": yes_no(tr_present),
                    "Reference Present (Yes/No)": yes_no(ref_present),
                    "Grade Present (Yes/No)": yes_no(grade_present),
                    "Source Provider": (row["source_provider"] or "").strip() or "fawazahmed0/hadith-api@1",
                    "Book Slug": slug,
                }
            )

        books_out[slug] = b
        print(
            f"  present={b['narrator_present']} absent={b['narrator_absent']} "
            f"verified={b['verified_match']} mismatch={b['mismatch']} "
            f"unverifiable={b['missing_unverifiable']} source_has_db_empty={b['missing_but_source_has']}",
            flush=True,
        )

    conn.close()
    DB.unlink(missing_ok=True)

    fields = [
        "Book",
        "Hadith Number",
        "Narrator Present (Yes/No)",
        "Narrator Value",
        "Authenticated Extraction",
        "Extraction Method",
        "Verification Status",
        "Reason if Narrator missing/mismatch",
        "Arabic Present (Yes/No)",
        "Translation Present (Yes/No)",
        "Reference Present (Yes/No)",
        "Grade Present (Yes/No)",
        "Source Provider",
        "Book Slug",
    ]
    with REPORT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(csv_rows)

    # Load rebuild totals if available
    rebuild_path = OUT_DIR / "NARRATOR_REBUILD_REPORT.json"
    rebuild = {}
    if rebuild_path.exists():
        rebuild = json.loads(rebuild_path.read_text(encoding="utf-8"))

    summary = {
        "generated_at": generated_at,
        "policy": [
            "Never invent narrator names with AI.",
            "Every narrator verified against authenticated fawazahmed0/hadith-api@1 editions.",
            "Unverifiable narrators left empty.",
        ],
        "source": "fawazahmed0/hadith-api@1",
        "rebuild_totals": rebuild.get("totals"),
        "totals": {
            "total_hadith": totals["total"],
            "narrator_present": totals["narrator_present"],
            "narrator_absent": totals["narrator_absent"],
            "verified_match": totals["verified_match"],
            "mismatch": totals["mismatch"],
            "missing_unverifiable": totals["missing_unverifiable"],
            "missing_but_source_has": totals["missing_but_source_has"],
            "verification_status_counts": dict(reason_totals),
            "narrators_recovered_new": (rebuild.get("totals") or {}).get("recovered_new"),
        },
        "books": books_out,
        "artifacts": {
            "csv": str(REPORT_CSV.relative_to(ROOT)),
            "json": str(REPORT_JSON.relative_to(ROOT)),
            "md": str(REPORT_MD.relative_to(ROOT)),
            "rebuild_report": "reports/verification/NARRATOR_REBUILD_REPORT.md",
        },
    }
    REPORT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT_MD.write_text(_md(summary), encoding="utf-8")
    print(f"Wrote {REPORT_CSV} ({len(csv_rows)} rows)")
    print(json.dumps(summary["totals"], indent=2, ensure_ascii=False))
    return 0


def _md(summary: dict) -> str:
    t = summary["totals"]
    r = summary.get("rebuild_totals") or {}
    lines = [
        "# Hadith Forensic Audit — Narrators (Second Report)",
        "",
        f"Generated: `{summary['generated_at']}`",
        "",
        "## Policy",
        "",
        "- Never invent narrator names with AI.",
        "- Every stored narrator re-checked against authenticated English + Arabic editions.",
        "- If unverifiable in authenticated source text → empty.",
        "",
        "## Narrators recovered (from rebuild)",
        "",
        f"| Metric | Count |",
        f"|--------|------:|",
        f"| Newly recovered narrators | **{t.get('narrators_recovered_new', r.get('recovered_new', '—'))}** |",
        f"| Present before rebuild | {r.get('before_present', '—')} |",
        f"| Present after rebuild | **{r.get('after_present', t['narrator_present'])}** |",
        f"| Still missing (unverifiable) | **{t['narrator_absent']}** |",
        "",
        "## Post-rebuild verification",
        "",
        f"| Metric | Count |",
        f"|--------|------:|",
        f"| Total Hadith | **{t['total_hadith']}** |",
        f"| Narrator present | **{t['narrator_present']}** |",
        f"| Narrator absent | **{t['narrator_absent']}** |",
        f"| Verified match (DB == authenticated extraction) | **{t['verified_match']}** |",
        f"| Mismatch | **{t['mismatch']}** |",
        f"| Missing & unverifiable in source | **{t['missing_unverifiable']}** |",
        f"| Missing but source has extractable narrator | **{t['missing_but_source_has']}** |",
        "",
        "## Per collection",
        "",
    ]
    for slug, b in summary["books"].items():
        lines += [
            f"### {b['book']} (`{slug}`)",
            "",
            f"| Metric | Count |",
            f"|--------|------:|",
            f"| Total | {b['total']} |",
            f"| Narrator present | **{b['narrator_present']}** |",
            f"| Narrator absent | **{b['narrator_absent']}** |",
            f"| Verified match | {b['verified_match']} |",
            f"| Mismatch | {b['mismatch']} |",
            f"| Missing unverifiable | {b['missing_unverifiable']} |",
            f"| Missing but source has | {b['missing_but_source_has']} |",
            "",
        ]
    lines += [
        "## Manual verification CSV",
        "",
        "`reports/verification/HADITH_FORENSIC_AUDIT_NARRATORS.csv` — one row per Hadith.",
        "",
        "Columns include Book, Hadith Number, Narrator Present, Narrator Value, "
        "Authenticated Extraction, Extraction Method, Verification Status, Reason.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
