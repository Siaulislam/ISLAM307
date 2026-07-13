#!/usr/bin/env python3
"""Regression: narrator extraction must use ONLY the Arabic Sanad (Isnad)."""

from __future__ import annotations

import gzip
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from hadith.hadith_meta import _cut_isnad_ar, _fold_ar, extract_ravi_chain  # noqa: E402

DB_GZ = ROOT / "app/assets/databases/hadith.db.gz"
OUT = ROOT / "reports/verification/SANAD_ONLY_NARRATOR_EXTRACTION.md"


def _load_db() -> sqlite3.Connection:
    data = gzip.open(DB_GZ, "rb").read()
    tf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tf.write(data)
    tf.close()
    return sqlite3.connect(tf.name)


def _has(chain: list[str], *needles: str) -> bool:
    joined = " | ".join(_fold_ar(c) for c in chain)
    return all(_fold_ar(n) in joined for n in needles)


def _lacks(chain: list[str], *needles: str) -> bool:
    joined = " | ".join(_fold_ar(c) for c in chain)
    return all(_fold_ar(n) not in joined for n in needles)


def main() -> int:
    con = _load_db()
    bid = con.execute(
        "SELECT id FROM books WHERE slug LIKE '%bukhari%' OR name_en LIKE '%Bukhari%' LIMIT 1"
    ).fetchone()[0]

    cases = []

    def row(n: int) -> tuple[str, str | None]:
        return con.execute(
            "SELECT text_ar, narrator FROM hadiths WHERE book_id=? AND hadith_number=? ORDER BY id LIMIT 1",
            (bid, n),
        ).fetchone()

    # Example 1 — Bukhari 1: stop before إنما الأعمال; include عمر; no matn.
    ar, nar = row(1)
    chain = extract_ravi_chain(ar, primary=nar)
    ok = (
        _has(chain, "الحميدي", "سفيان", "يحيى", "محمد", "علقمة", "عمر")
        and _lacks(chain, "إنما", "امرئ", "هجرته")
        and "إنما" not in _cut_isnad_ar(ar)
    )
    cases.append(("Bukhari 1 — sanad only (no matn quote)", ok, chain))

    # Example 2 — Bukhari 2: Aisha; NOT الحارث.
    ar, nar = row(2)
    chain = extract_ravi_chain(ar, primary=nar)
    ok = _has(chain, "عبد الله بن يوسف", "مالك", "هشام", "عائشة") and _lacks(
        chain, "الحارث", "هرقل"
    )
    cases.append(("Bukhari 2 — stop at Aisha (no الحارث)", ok, chain))

    # Example 4 / Heraclius — Bukhari 7: through ابن عباس; NOT أبو سفيان / هرقل.
    ar, nar = row(7)
    chain = extract_ravi_chain(ar, primary=nar)
    ok = _has(chain, "أبو اليمان", "شعيب", "الزهري", "عبيد الله", "عباس") and _lacks(
        chain, "هرقل", "ابا سفيان", "ابو سفيان", "سالتك"
    )
    # Allow حنظلة بن أبي سفيان style names elsewhere — here must not be bare أبو سفيان.
    ok = ok and not any(_fold_ar(c).startswith(("ابو سفيان", "ابا سفيان")) for c in chain)
    cases.append(("Bukhari 7 — Heraclius story (no هرقل / أبو سفيان)", ok, chain))

    # Bukhari 51 — same Heraclius continuation leak class.
    ar, nar = row(51)
    chain = extract_ravi_chain(ar, primary=nar)
    ok = _has(chain, "ابن شهاب", "عبيد الله", "عباس") and _lacks(
        chain, "هرقل", "سالتك", "يزيدون", "ابو سفيان", "ابا سفيان"
    )
    cases.append(("Bukhari 51 — no Heraclius matn leak", ok, chain))

    # Scan Bukhari 1–200 for common matn leaks.
    leak_re_needles = (
        "هرقل",
        "سالتك",
        "يزيدون",
        "الحارث بن هشام",
        "انما الاعمال",
        "فزعمت",
        "القريش",
    )
    leaks = []
    seen = set()
    for num, ar, nar in con.execute(
        "SELECT hadith_number, text_ar, narrator FROM hadiths "
        "WHERE book_id=? AND hadith_number BETWEEN 1 AND 200 ORDER BY hadith_number, id",
        (bid,),
    ):
        if num in seen:
            continue
        seen.add(num)
        chain = extract_ravi_chain(ar, primary=nar)
        for c in chain:
            f = _fold_ar(c)
            if any(n in f for n in leak_re_needles) or f.startswith(("ابو سفيان", "ابا سفيان")):
                leaks.append((num, c))
                break
    cases.append((f"Bukhari 1–200 matn-leak scan ({len(leaks)} leaks)", len(leaks) == 0, leaks[:10]))

    passed = sum(1 for _, ok, _ in cases if ok)
    lines = [
        "# Sanad-only narrator extraction",
        "",
        "Narrators must come **only** from the Arabic Isnad. Matn names are never narrators.",
        "",
        f"**Result:** {passed}/{len(cases)} checks passed.",
        "",
    ]
    for title, ok, detail in cases:
        mark = "PASS" if ok else "FAIL"
        lines.append(f"- **{mark}** — {title}")
        lines.append(f"  - `{detail}`")
        lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(OUT.read_text())
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
