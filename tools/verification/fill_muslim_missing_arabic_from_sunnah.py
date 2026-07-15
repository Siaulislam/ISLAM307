#!/usr/bin/env python3
"""Fill missing Sahih Muslim Arabic text from sunnah.com only (no AI).

Rules:
  - Only update rows where text_ar is empty / has no Arabic script.
  - Fetch https://sunnah.com/muslim:{n} (via r.jina.ai markdown mirror).
  - Verify the page Reference is Sahih Muslim {n}.
  - Copy Arabic exactly (markdown narrator links unwrapped to visible text).
  - Skip if that Arabic already exists on another Muslim hadith (duplicate guard).
  - Never invent or rewrite Arabic.
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith.db"
CACHE = ROOT / "tools" / "verification" / "cache" / "sunnah_pages"
OUT_DIR = ROOT / "reports" / "verification"
REPORT_JSON = OUT_DIR / "MUSLIM_SUNNAH_ARABIC_FILL.json"
REPORT_MD = OUT_DIR / "MUSLIM_SUNNAH_ARABIC_FILL.md"

AR_RE = re.compile(r"[\u0600-\u06FF]")
DIAC = re.compile(r"[\u064B-\u065F\u0670\u0640]")


def norm_ar(text: str) -> str:
    t = DIAC.sub("", text or "")
    t = re.sub(r"[^\u0600-\u06FFa-zA-Z0-9]", "", t)
    return t


def has_arabic(text: str | None) -> bool:
    return bool(text and AR_RE.search(text))


def fetch_sunnah_md(n: int) -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    url = f"https://sunnah.com/muslim:{n}"
    cpath = CACHE / f"muslim_{n}.md"
    if cpath.exists() and cpath.stat().st_size > 400:
        return cpath.read_text(encoding="utf-8")
    jurl = "https://r.jina.ai/" + url
    req = urllib.request.Request(
        jurl,
        headers={
            "User-Agent": "Mozilla/5.0 ISLAM307-muslim-ar-fill/1.0",
            "Accept": "text/markdown",
            "X-Return-Format": "markdown",
            "X-Wait-For-Selector": ".actualHadithContainer",
        },
    )
    last_err: Exception | None = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = resp.read().decode("utf-8", "replace")
            cpath.write_text(body, encoding="utf-8")
            time.sleep(0.5)
            return body
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(1.4 * (attempt + 1))
    raise RuntimeError(f"fetch failed muslim:{n}: {last_err}")


def extract_arabic(md: str, n: int) -> tuple[str | None, str]:
    if f"sunnah.com/muslim:{n}" not in md and f"sunnah.com/muslim:{n}a" not in md:
        # URL source may be muslim:N while reference is N / Na / Nb
        if f"muslim:{n}" not in md:
            return None, "page_url_mismatch"
    if "returned error 404" in md.lower() or "error 404" in md.lower():
        return None, "sunnah_404"
    ref = re.search(r"\*\*Reference\*\*", md)
    if not ref:
        return None, "missing_reference_heading"
    after = md[ref.start() : ref.start() + 320]
    # sunnah.com often labels variants as 8a / 16b while the URL is /muslim:8
    if not re.search(rf"Sahih Muslim\s+{n}([a-z]+)?\b", after):
        return None, "reference_number_mismatch"
    before = md[: ref.start()]
    paras = re.split(r"\n\s*\n", before)
    cands: list[str] = []
    for p in paras:
        if len(AR_RE.findall(p)) < 40:
            continue
        plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", p)
        plain = re.sub(r"\s+", " ", plain).strip()
        if plain.startswith("باب") and "حَدَّث" not in plain and "حدث" not in plain and len(AR_RE.findall(plain)) < 150:
            continue
        cands.append(plain)
    if not cands:
        return None, "no_arabic_on_page"
    text = cands[-1]
    if len(AR_RE.findall(text)) < 40:
        return None, "arabic_too_short"
    return text, "ok"


def open_db() -> sqlite3.Connection:
    DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def existing_arabic_index(conn: sqlite3.Connection) -> dict[str, int]:
    out: dict[str, int] = {}
    for r in conn.execute(
        "SELECT hadith_number, text_ar FROM hadiths WHERE book_id=2 AND length(trim(coalesce(text_ar,''))) > 20"
    ):
        if has_arabic(r["text_ar"]):
            key = norm_ar(r["text_ar"])
            if key and key not in out:
                out[key] = int(r["hadith_number"])
    return out


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = open_db()
    missing = [
        int(r["hadith_number"])
        for r in conn.execute(
            "SELECT hadith_number, text_ar FROM hadiths WHERE book_id=2 ORDER BY hadith_number"
        )
        if not has_arabic(r["text_ar"])
    ]
    existing = existing_arabic_index(conn)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "policy": [
            "Only fill empty Muslim text_ar",
            "Source: sunnah.com/muslim:{n} exact Arabic copy",
            "No AI generation",
            "Skip duplicate Arabic already present under another number",
            "Verify Sahih Muslim {n} on page before update",
        ],
        "missing_before": len(missing),
        "filled": [],
        "skipped": [],
        "errors": [],
    }

    for i, n in enumerate(missing, 1):
        print(f"[{i}/{len(missing)}] muslim:{n}")
        try:
            md = fetch_sunnah_md(n)
            arabic, reason = extract_arabic(md, n)
            if not arabic:
                report["skipped"].append({"n": n, "reason": reason, "url": f"https://sunnah.com/muslim:{n}"})
                continue
            key = norm_ar(arabic)
            if key in existing:
                report["skipped"].append(
                    {
                        "n": n,
                        "reason": "duplicate_arabic_already_at",
                        "existing_hadith_number": existing[key],
                        "url": f"https://sunnah.com/muslim:{n}",
                    }
                )
                continue
            # exact update only empty arabic
            cur = conn.execute(
                "SELECT id, text_ar FROM hadiths WHERE book_id=2 AND hadith_number=?",
                (n,),
            ).fetchone()
            if not cur:
                report["errors"].append({"n": n, "reason": "row_missing_in_db"})
                continue
            if has_arabic(cur["text_ar"]):
                report["skipped"].append({"n": n, "reason": "already_has_arabic"})
                continue
            conn.execute("UPDATE hadiths SET text_ar=? WHERE id=?", (arabic, cur["id"]))
            # keep FTS in sync when row exists
            conn.execute(
                "UPDATE hadith_fts SET text_ar=? WHERE hadith_id=? AND book_slug='muslim'",
                (arabic, cur["id"]),
            )
            existing[key] = n
            report["filled"].append(
                {
                    "n": n,
                    "url": f"https://sunnah.com/muslim:{n}",
                    "arabic_chars": len(AR_RE.findall(arabic)),
                    "arabic_preview": arabic[:160],
                }
            )
        except Exception as e:  # noqa: BLE001
            report["errors"].append({"n": n, "reason": str(e)})

    conn.commit()
    conn.execute("PRAGMA wal_checkpoint(FULL)")
    conn.close()
    # recompress from checkpointed DB bytes
    GZ.write_bytes(gzip.compress(DB.read_bytes(), compresslevel=9))
    # reopen for remaining count
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    report["filled_count"] = len(report["filled"])
    report["skipped_count"] = len(report["skipped"])
    report["error_count"] = len(report["errors"])
    remaining = [
        int(r["hadith_number"])
        for r in conn.execute("SELECT hadith_number, text_ar FROM hadiths WHERE book_id=2")
        if not has_arabic(r["text_ar"])
    ]
    report["missing_after"] = len(remaining)
    report["remaining_numbers"] = remaining
    conn.close()

    REPORT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Muslim missing Arabic fill (sunnah.com)",
        "",
        f"- Generated: `{report['generated_at']}`",
        f"- Missing before: **{report['missing_before']}**",
        f"- Filled from sunnah.com: **{report['filled_count']}**",
        f"- Skipped: **{report['skipped_count']}**",
        f"- Errors: **{report['error_count']}**",
        f"- Missing after: **{report['missing_after']}**",
        "",
        "## Policy",
        "",
    ]
    lines += [f"- {p}" for p in report["policy"]]
    lines += ["", "## Filled (sample)", ""]
    for row in report["filled"][:25]:
        lines.append(f"- `{row['n']}` ← {row['url']} ({row['arabic_chars']} Arabic chars)")
    if len(report["filled"]) > 25:
        lines.append(f"- … +{len(report['filled']) - 25} more")
    lines += ["", "## Skipped reasons", ""]
    from collections import Counter

    c = Counter(s["reason"] for s in report["skipped"])
    for reason, count in c.most_common():
        lines.append(f"- `{reason}`: **{count}**")
    if remaining:
        lines += ["", "## Still missing", "", ", ".join(str(x) for x in remaining[:80])]
        if len(remaining) > 80:
            lines.append(f"… +{len(remaining) - 80} more")
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("missing_before", "filled_count", "skipped_count", "error_count", "missing_after")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
