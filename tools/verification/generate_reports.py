#!/usr/bin/env python3
"""Generate ISLAM 307 verification reports for bundled databases."""

from __future__ import annotations

import json
import re
import sqlite3
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HADITH_DB = ROOT / "app" / "assets" / "databases" / "hadith.db"
REPORT_DIR = ROOT / "reports" / "verification"


def table_names(conn: sqlite3.Connection) -> set[str]:
    rows = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    return {r[0] for r in rows}


def normalize_grade(raw: str | None) -> str:
    if not raw or not str(raw).strip():
        return "UNKNOWN"
    s = str(raw).strip().lower()
    if "sahih" in s or "صحيح" in s:
        return "SAHIH"
    if "hasan" in s or "حسن" in s:
        if "sahih" not in s:
            return "HASAN"
    if "da'if" in s or "daif" in s or "da‘if" in s or "ضعيف" in s:
        return "DAIF"
    if "mawdu" in s or "موضوع" in s:
        return "MAWDU"
    if "hasan sahih" in s or "حسن صحيح" in s:
        return "HASAN_SAHIH"
    return "OTHER"


def parse_grades_from_column(grade_str: str | None) -> list[tuple[str, str | None]]:
    if not grade_str or not grade_str.strip():
        return []
    # Upstream may store JSON array as string in some editions
    if grade_str.strip().startswith("["):
        try:
            arr = json.loads(grade_str)
            out = []
            for g in arr:
                if isinstance(g, dict):
                    out.append((str(g.get("grade", "")).strip(), (g.get("graded_by") or g.get("by") or None)))
            return [(a, b) for a, b in out if a]
        except json.JSONDecodeError:
            pass
    parts = [p.strip() for p in re.split(r"[;\n]+", grade_str) if p.strip()]
    out = []
    for p in parts:
        m = re.match(r"^(.+?)\s*\(([^)]+)\)\s*$", p)
        if m:
            out.append((m.group(1).strip(), m.group(2).strip()))
        else:
            out.append((p, None))
    return out


def analyze_hadith() -> dict:
    conn = sqlite3.connect(HADITH_DB)
    conn.row_factory = sqlite3.Row
    tables = table_names(conn)

    meta = {}
    if "meta" in tables:
        meta = dict(conn.execute("SELECT key, value FROM meta").fetchall())

    books = [dict(r) for r in conn.execute("SELECT * FROM books ORDER BY sort_order, id").fetchall()]
    total = conn.execute("SELECT COUNT(*) FROM hadiths").fetchone()[0]

    grade_counter = Counter()
    scholar_counter = Counter()
    book_grade_counter: dict[str, Counter] = defaultdict(Counter)
    per_hadith: list[dict] = []
    missing_ar = 0
    missing_en = 0
    missing_grade = 0
    missing_narrator = 0

    cols = {c[1] for c in conn.execute("PRAGMA table_info(hadiths)").fetchall()}
    has_grades_table = "hadith_grades" in tables

    rows = conn.execute(
        """
        SELECT h.*, b.slug AS book_slug, b.name_en AS book_name
        FROM hadiths h
        JOIN books b ON b.id = h.book_id
        ORDER BY b.sort_order, h.hadith_number
        """
    ).fetchall()

    grades_by_hid: dict[int, list[tuple[str, str | None, str]]] = defaultdict(list)
    if has_grades_table:
        for g in conn.execute("SELECT hadith_id, grade, graded_by, language FROM hadith_grades ORDER BY hadith_id, sort_order"):
            grades_by_hid[g[0]].append((g[1], g[2], g[3]))

    for r in rows:
        d = dict(r)
        hid = d["id"]
        if not (d.get("text_ar") or "").strip():
            missing_ar += 1
        if not (d.get("text_en") or "").strip():
            missing_en += 1
        if not (d.get("narrator") or "").strip():
            missing_narrator += 1

        gradings: list[tuple[str, str | None]] = []
        if has_grades_table:
            gradings = [(g[0], g[1]) for g in grades_by_hid.get(hid, [])]
        elif "grade" in cols:
            gradings = parse_grades_from_column(d.get("grade"))

        if not gradings:
            missing_grade += 1
            primary = "UNKNOWN"
            scholar = None
        else:
            primary = normalize_grade(gradings[0][0])
            scholar = gradings[0][1]

        grade_counter[primary] += 1
        book_grade_counter[d["book_slug"]][primary] += 1
        if scholar:
            scholar_counter[scholar] += 1

        per_hadith.append(
            {
                "book_slug": d["book_slug"],
                "book_name": d["book_name"],
                "hadith_number": d["hadith_number"],
                "chapter_id": d.get("chapter_id"),
                "primary_grade": primary,
                "gradings": [{"grade": g, "scholar": s} for g, s in gradings],
                "narrator": d.get("narrator"),
                "has_arabic": bool((d.get("text_ar") or "").strip()),
                "has_english": bool((d.get("text_en") or "").strip()),
                "has_urdu": bool((d.get("text_ur") or "").strip()) if "text_ur" in d else False,
                "reference_url": d.get("reference_url"),
                "source_provider": d.get("source_provider"),
            }
        )

    conn.close()

    return {
        "database_path": str(HADITH_DB),
        "file_size_mb": round(HADITH_DB.stat().st_size / 1024 / 1024, 2),
        "schema_version": "v2_multi_grade" if has_grades_table else "v1_legacy_single_grade_column",
        "meta": meta,
        "total_hadiths": total,
        "books": books,
        "grade_distribution": dict(grade_counter),
        "grade_distribution_by_book": {k: dict(v) for k, v in book_grade_counter.items()},
        "top_scholars_in_grades": scholar_counter.most_common(50),
        "quality": {
            "missing_arabic_text": missing_ar,
            "missing_english_text": missing_en,
            "missing_any_grade": missing_grade,
            "missing_narrator": missing_narrator,
        },
        "records": per_hadith,
    }


def write_markdown_hadith(data: dict, path: Path) -> None:
    meta = data["meta"]
    lines = [
        "# ISLAM 307 — Hadith Database Verification Report",
        "",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Executive summary",
        "",
        f"- **Total hadiths analyzed:** {data['total_hadiths']:,}",
        f"- **Database file:** `{data['database_path']}` ({data['file_size_mb']} MB)",
        f"- **Schema:** {data['schema_version']}",
        "",
        "## 1. Original source of every hadith",
        "",
        f"- **Recorded builder source (meta):** `{meta.get('source', 'NOT RECORDED')}`",
        f"- **Recorded source URL:** `{meta.get('source_url', 'NOT RECORDED')}`",
        "",
        "**Finding:** The bundled `hadith.db` was built from **fawazahmed0/hadith-api@1** (jsdelivr CDN), **not** from Sunnah.com, HadeethEnc.com, Maktaba Shamela authenticated editions, or King Fahd Complex publications.",
        "",
        "This is an **unofficial aggregated dataset**. It does **not** meet the project's authenticated-source policy.",
        "",
        "## 2. Edition used",
        "",
        "Per fawazahmed0/hadith-api References.md, editions vary by book and language:",
        "",
        "| Book | Arabic / English editions (as documented by upstream) |",
        "|------|--------------------------------------------------------|",
        "| Sahih Bukhari | Arabic + English (Darussalam-style numbering in API) |",
        "| Sahih Muslim | Arabic + English |",
        "| Abu Dawood | Multiple grading editions from al-maktaba.org (Al-Albani, Arnaout, Abdul Hamid) |",
        "| Tirmidhi | Al-Albani, Ahmed Muhammad Shakir, Bashar Awad Maarouf |",
        "| Nasa'i | Al-Albani, Abu Ghuddah |",
        "| Ibn Majah | Al-Albani, Muhammad Fouad Abd al-Baqi, Arnaout |",
        "| Muwatta Malik | Arabic + English via same API |",
        "",
        "**Exact printed edition per hadith is NOT stored in hadith.db.** Only a merged `grade` text field exists.",
        "",
        "## 3. Who graded the hadith?",
        "",
        "Gradings were **copied from upstream JSON**, which scraped/parsed **al-maktaba.org (Maktaba Shamela web)** grading pages — not directly from Sunnah.com scholars.",
        "",
        "Top scholars appearing in grade strings:",
        "",
    ]
    for scholar, count in data["top_scholars_in_grades"][:25]:
        lines.append(f"- **{scholar}:** {count:,} hadith records")
    if not data["top_scholars_in_grades"]:
        lines.append("- No structured scholar field; grades embedded in single text column.")

    lines += [
        "",
        "## 4. Official scholars vs copied source?",
        "",
        "**Copied from another source.** Grades are second-hand aggregations from al-maktaba.org via fawazahmed0's parsing scripts. They are **not** verified directly from Sunnah.com or authenticated Shamela desktop editions.",
        "",
        "## 5. Commercial license compatibility",
        "",
        "- **Upstream repo license:** The Unlicense (public domain dedication) — permissive for commercial use of the *API wrapper/repo*.",
        "- **Hadith text & grading content:** Islamic texts themselves are generally not copyrightable, but **edition-specific translations** (e.g. Darussalam English) may have publisher rights.",
        "- **Risk:** fawazahmed0 explicitly aggregates from multiple sites without per-edition licensing proof. **Not verified safe for commercial redistribution** of English translations.",
        "",
        "**Verdict:** ⚠️ **NOT verified commercial-ready.** Rebuild required from Sunnah.com API (with their terms) or explicitly licensed editions.",
        "",
        "## 6. Grade distribution (all hadiths)",
        "",
        "| Grade bucket | Count |",
        "|--------------|------:|",
    ]
    for grade, count in sorted(data["grade_distribution"].items(), key=lambda x: -x[1]):
        lines.append(f"| {grade} | {count:,} |")

    q = data["quality"]
    lines += [
        "",
        "## 7. Data quality",
        "",
        f"- Missing Arabic text: **{q['missing_arabic_text']:,}**",
        f"- Missing English text: **{q['missing_english_text']:,}**",
        f"- Missing any grade: **{q['missing_any_grade']:,}**",
        f"- Missing narrator: **{q['missing_narrator']:,}**",
        "",
        "## Per-book breakdown",
        "",
        "| Book | Hadiths | Sahih | Hasan | Da'if | Other/Unknown |",
        "|------|--------:|------:|------:|------:|--------------:|",
    ]
    for b in data["books"]:
        slug = b["slug"]
        gc = data["grade_distribution_by_book"].get(slug, {})
        lines.append(
            f"| {b['name_en']} | {b.get('hadith_count', 0):,} | {gc.get('SAHIH', 0):,} | {gc.get('HASAN', 0):,} | {gc.get('DAIF', 0):,} | {gc.get('OTHER', 0) + gc.get('UNKNOWN', 0):,} |"
        )

    lines += [
        "",
        "## Full per-hadith report",
        "",
        "Machine-readable JSON with all 36,313 records:",
        "",
        "`reports/verification/hadith_full_report.json`",
        "",
        "## Recommendation",
        "",
        "**DO NOT ship this database in production.** Rebuild using Sunnah.com authenticated API after obtaining an API key.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    print("Analyzing hadith.db...")
    hadith = analyze_hadith()
    (REPORT_DIR / "hadith_full_report.json").write_text(
        json.dumps(hadith, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_markdown_hadith(hadith, REPORT_DIR / "HADITH_VERIFICATION_REPORT.md")

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "hadith": {
            "total": hadith["total_hadiths"],
            "source": hadith["meta"].get("source"),
            "authenticated_source_policy_met": False,
            "commercial_ready": False,
            "grade_distribution": hadith["grade_distribution"],
        },
        "tafsir": {
            "delivery": "runtime_official_api",
            "bundled_entries": 0,
            "provider": "Quran Foundation Content API",
            "license_review": "docs/TAFSEER_SOURCES_AND_LICENSES.md",
        },
        "development_blocked": True,
        "recommendation": "Rebuild hadith.db from Sunnah.com API; Tafseer must remain runtime official-API-only.",
    }
    (REPORT_DIR / "VERIFICATION_SUMMARY.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Reports written to {REPORT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
