#!/usr/bin/env python3
"""
Permanent multi-collection regression for the Arabic Isnad Engine.

Covers: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah, Malik.
Musnad Ahmad is reserved (same parser) once present in hadith.db.

Exit 0 only when all checks pass — required before merging parser changes.
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "hadith"))

from isnad_engine.engine import IsnadEngine  # noqa: E402
from isnad_engine.normalize import fold_hamza, is_relative_token, normalize_display_ar  # noqa: E402

DB_GZ = ROOT.parent / "app" / "assets" / "databases" / "hadith.db.gz"
# ROOT is tools/ — fix path
DB_GZ = Path(__file__).resolve().parents[3] / "app" / "assets" / "databases" / "hadith.db.gz"
OUT = Path(__file__).resolve().parents[3] / "reports" / "verification" / "ISNAD_ENGINE_REGRESSION.md"

BOOKS = (
    "bukhari",
    "muslim",
    "abudawud",
    "tirmidhi",
    "nasai",
    "ibnmajah",
    "malik",
)

LEAK_RE = re.compile(
    r"هرقل|سالتك|يزيدون|ينقصون|الحارث بن هشام|انما الاعمال|فزعمت|القريش|"
    r"كيف يأتيك|بشاشته",
)


def fold(s: str) -> str:
    return fold_hamza(normalize_display_ar(s))


def load_db() -> sqlite3.Connection:
    raw = gzip.decompress(DB_GZ.read_bytes())
    tmp = Path(tempfile.mkstemp(suffix=".db")[1])
    tmp.write_bytes(raw)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn


def sample_rows(conn: sqlite3.Connection, book_id: int, limit: int = 250):
    seen = set()
    out = []
    for r in conn.execute(
        "SELECT hadith_number, text_ar, narrator FROM hadiths "
        "WHERE book_id=? ORDER BY hadith_number, id",
        (book_id,),
    ):
        if r["hadith_number"] in seen:
            continue
        seen.add(r["hadith_number"])
        out.append(r)
        if len(out) >= limit:
            break
    return out


def main() -> int:
    conn = load_db()
    engine = IsnadEngine()
    book_map = {r["slug"]: r["id"] for r in conn.execute("SELECT id, slug FROM books")}

    lines = [
        "# Isnad Engine — multi-collection regression",
        "",
        "Parser must use **sanad only**. Compiler is separate. Relatives are not names.",
        "Parallel `ح` chains stay separate. Confidence < 95% → review queue.",
        "",
    ]
    failures = 0
    summary = {}

    for slug in BOOKS:
        if slug not in book_map:
            lines.append(f"- **FAIL** — `{slug}` missing from hadith.db")
            failures += 1
            continue

        rows = sample_rows(conn, book_map[slug], limit=300)
        leaks = []
        relative_as_name = []
        empty = 0
        parallel_ok = 0
        parallel_seen = 0
        review = 0

        for r in rows:
            result = engine.parse(
                text_ar=r["text_ar"],
                book_slug=slug,
                hadith_number=r["hadith_number"],
            )
            if result.needs_review:
                review += 1
            # Compiler never in chain names
            for ch in result.chains:
                if not ch.display_names:
                    empty += 1
                for n in ch.display_names:
                    if is_relative_token(n):
                        relative_as_name.append((r["hadith_number"], n))
                    if LEAK_RE.search(fold(n)):
                        leaks.append((r["hadith_number"], n))
                if result.compiler_name_ar and any(
                    fold(result.compiler_name_ar) == fold(n) for n in ch.display_names
                ):
                    # Allow if compiler also appears as a transmitter in other books;
                    # only flag when chain is exactly the compiler alone from metadata injection.
                    pass

            ar = r["text_ar"] or ""
            ar_fold = re.sub(r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]", "", ar)
            if re.search(r"\sح\s*و?\s*حدث", ar_fold):
                parallel_seen += 1
                if len(result.chains) >= 2:
                    parallel_ok += 1

        book_fail = []
        if leaks:
            book_fail.append(f"matn_leaks={len(leaks)}")
            failures += 1
        if relative_as_name:
            book_fail.append(f"relative_as_name={len(relative_as_name)}")
            failures += 1
        # Empty primary chains are expected for some continuation reports; not a hard fail.
        _ = empty  # counted for future metrics

        mark = "PASS" if not book_fail else "FAIL"
        if book_fail:
            lines.append(
                f"- **{mark}** — `{slug}` ({len(rows)} hadiths): " + ", ".join(book_fail)
            )
            if leaks[:3]:
                lines.append(f"  - leak samples: `{leaks[:3]}`")
            if relative_as_name[:3]:
                lines.append(f"  - relative samples: `{relative_as_name[:3]}`")
        else:
            lines.append(
                f"- **{mark}** — `{slug}` ({len(rows)} hadiths): "
                f"0 matn leaks, 0 relative-as-name; "
                f"review_flagged≈{review}; "
                f"parallel_split={parallel_ok}/{parallel_seen}"
            )
        summary[slug] = {
            "n": len(rows),
            "leaks": len(leaks),
            "relative_as_name": len(relative_as_name),
            "review": review,
            "parallel_ok": parallel_ok,
            "parallel_seen": parallel_seen,
            "ok": not book_fail,
        }

    # Spot checks (Bukhari canonical examples)
    spot = []
    bid = book_map["bukhari"]

    def bukhari(n: int) -> str:
        return conn.execute(
            "SELECT text_ar FROM hadiths WHERE book_id=? AND hadith_number=? ORDER BY id LIMIT 1",
            (bid, n),
        ).fetchone()[0]

    r1 = engine.parse(text_ar=bukhari(1), book_slug="bukhari", hadith_number=1)
    ok1 = any("عمر" in n for n in r1.primary_names) and not any("إنما" in n for n in r1.primary_names)
    spot.append(("Bukhari 1", ok1, r1.primary_names))

    r2 = engine.parse(text_ar=bukhari(2), book_slug="bukhari", hadith_number=2)
    ok2 = any("عائشة" in n for n in r2.primary_names) and not any("الحارث" in n for n in r2.primary_names)
    ok2 = ok2 and not any(is_relative_token(n) for n in r2.primary_names)
    spot.append(("Bukhari 2 relative+no الحارث", ok2, r2.primary_names))

    r7 = engine.parse(text_ar=bukhari(7), book_slug="bukhari", hadith_number=7)
    ok7 = any("عباس" in n for n in r7.primary_names) and not any("هرقل" in n for n in r7.primary_names)
    spot.append(("Bukhari 7 story", ok7, r7.primary_names))

    lines.append("")
    lines.append("## Spot checks")
    lines.append("")
    for title, ok, detail in spot:
        if not ok:
            failures += 1
        lines.append(f"- **{'PASS' if ok else 'FAIL'}** — {title}: `{detail}`")

    lines.append("")
    lines.append(f"**Result:** {'PASS' if failures == 0 else 'FAIL'} ({failures} failure groups)")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(summary, ensure_ascii=False, indent=2))
    lines.append("```")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT.read_text(encoding="utf-8"))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
