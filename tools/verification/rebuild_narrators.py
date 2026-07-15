#!/usr/bin/env python3
"""Rebuild hadith.narrator from authenticated Sunni editions only (no AI).

Source: fawazahmed0/hadith-api@1 English + Arabic editions (same provenance as hadith.db).

Rules:
  - Never invent narrator names.
  - Extract only with deterministic patterns from authenticated text.
  - Prefer English companion / attributed narrator labels when verifiable.
  - Fall back to last verified Arabic isnad name before the Prophet ﷺ.
  - If neither yields a verifiable name, leave narrator empty.

Writes:
  - Updates app/assets/databases/hadith.db.gz
  - reports/verification/NARRATOR_REBUILD_REPORT.{md,json}
  - Then intended to be followed by forensic_hadith_audit_narrators.py
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import sys
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "hadith"))

from hadith_meta import (  # noqa: E402
    _clean_name_ar,
    _clean_name_en,
    _fold_ar,
    _is_prophet_token,
    extract_ravi_chain,
)

GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith_narrator_rebuild.db"
OUT_DIR = ROOT / "reports" / "verification"
REPORT_MD = OUT_DIR / "NARRATOR_REBUILD_REPORT.md"
REPORT_JSON = OUT_DIR / "NARRATOR_REBUILD_REPORT.json"

SLUGS = ("bukhari", "muslim", "abudawud", "tirmidhi")
CDN = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions"

NOISE_EN = re.compile(
    r"^(?:it|this|the above|another|a tradition|a hadith|narrated|reported|one|some|people|"
    r"he|she|they|we|i|and|or|from|that|when|while|after|before|also|same|"
    r"the prophet|allah|messenger|narrator not mentioned|see translation|"
    r"the same|the like)\b",
    re.I,
)
BAD_AR = re.compile(r"بهذا|الحديث|قال|قالت|صلى|ﷺ|نحوه|بإسناده|إسناده")
RELATIVE_ONLY = re.compile(r"^(?:ابيه|امه|اباها|جده|اخيه|عمه|خاله)$")


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307-narrator-rebuild/1.0"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.load(resp)


def load_edition(slug: str, prefix: str) -> dict[int, dict]:
    data = fetch_json(f"{CDN}/{prefix}-{slug}.json")
    out: dict[int, dict] = {}
    for h in data.get("hadiths") or []:
        try:
            n = int(h.get("hadithnumber") or 0)
        except (TypeError, ValueError):
            continue
        if n:
            out[n] = h
    return out


def looks_like_en_name(name: str) -> bool:
    name = (name or "").strip(" '\"`")
    if not name or len(name) < 2 or len(name) > 90:
        return False
    if NOISE_EN.match(name):
        return False
    if not re.search(r"[A-Za-z]", name):
        return False
    if re.search(
        r"\bnarrated\b|\breported\b|\btradition\b|\bchain\b|\babove\b|\bmentioned\b|"
        r"\bhadith\b|\btransmitted\b|\btranslation\b",
        name,
        re.I,
    ):
        return False
    if len(re.split(r"\s+", name)) > 12:
        return False
    if _is_prophet_token(name):
        return False
    return True


def looks_like_ar_name(name: str) -> bool:
    name = (name or "").strip(" ،,;:")
    if not name or len(name) < 3 or len(name) > 80:
        return False
    if BAD_AR.search(name):
        return False
    if RELATIVE_ONLY.match(_fold_ar(name)):
        return False
    if _is_prophet_token(name):
        return False
    if not re.search(r"[\u0600-\u06FF]", name):
        return False
    return True


# Ordered English extractors — first match wins (authenticated wording only).
EN_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("narrated_colon", re.compile(r"^\s*Narrated\s+(.+?)(?:\s*:|\s*\(|\s*$)", re.I | re.S)),
    (
        "auth_narrated",
        re.compile(
            r"^\s*It (?:is|was) narrated on the authority of\s+(.+?)(?:\s+that\b|\s*:)",
            re.I,
        ),
    ),
    (
        "auth_reported",
        re.compile(
            r"^\s*It (?:is|was) reported on the authority of\s+(.+?)(?:\s+that\b|\s*:)",
            re.I,
        ),
    ),
    (
        "it_has_been_auth",
        re.compile(
            r"^\s*It has been (?:narrated|reported|related|transmitted) on the authority of\s+(.+?)"
            r"(?:\s+that\b|\s*:|\s+who\b|\s*,|\s*\.)",
            re.I,
        ),
    ),
    (
        "this_hadith_auth",
        re.compile(
            r"^\s*(?:This hadith|A hadith like this|The above hadith|The same hadith)"
            r"[^.!?]{0,120}?\bon the authority of\s+(.+?)"
            r"(?:\s+with\b|\s+that\b|\s+from\b|\s+through\b|\s*,|\s*\.|$)",
            re.I,
        ),
    ),
    (
        "this_hadith_by",
        re.compile(
            r"^\s*(?:This hadith|A hadith like this)"
            r"[^.!?]{0,80}?\b(?:narrated|reported|transmitted)\s+by\s+(.+?)"
            r"(?:\s+with\b|\s+through\b|\s+on\b|\s*,|\s*\.|$)",
            re.I,
        ),
    ),
    (
        "it_was_from",
        re.compile(r"^\s*It was narrated from\s+(.+?)(?:\s+that\b|\s*,\s*who\b|\s*:)", re.I),
    ),
    (
        "it_was_that",
        re.compile(r"^\s*It was narrated that\s+(.+?)(?:\s+said\b|\s*:)", re.I),
    ),
    ("x_narrated_that", re.compile(r"^\s*(.+?)\s+narrated\s+that\s*:?", re.I)),
    ("x_narrated_colon", re.compile(r"^\s*(.+?)\s+narrated\s*:", re.I)),
    (
        "x_narrated_auth",
        re.compile(r"^\s*(.+?)\s+narrated\s+on the authority of\b", re.I),
    ),
    ("x_reported_colon", re.compile(r"^\s*(.+?)\s+reported\s*:", re.I)),
    ("x_reported_that", re.compile(r"^\s*(.+?)\s+reported\s+that\b", re.I)),
    (
        "x_reported_auth",
        re.compile(r"^\s*(.+?)\s+reported\s+on the authority of\b", re.I),
    ),
    (
        "x_reported_messenger",
        re.compile(
            r"^\s*(.+?)\s+reported\s+Allah'?s\s+(?:Messenger|Apostle)\b",
            re.I,
        ),
    ),
    (
        "x_honor_reported",
        re.compile(
            r"^\s*(.+?)\s*\(\s*Allah be pleased[^)]*\)\s*reported\b",
            re.I,
        ),
    ),
    ("x_said_colon", re.compile(r"^\s*(.+?)\s+said\s*:", re.I)),
]

ON_AUTH = re.compile(r"on the authority of\s+([^,.\n]+)", re.I)
ON_AUTH_SHORT = re.compile(r"on authority of\s+([^,.\n]+)", re.I)


def extract_en_primary(text: str) -> tuple[str | None, str | None]:
    t = (text or "").strip()
    if not t:
        return None, None
    for label, pat in EN_PATTERNS:
        m = pat.match(t)
        if not m:
            continue
        name = _clean_name_en(m.group(1))
        # Strip trailing honorific crumbs left in capture
        name = re.sub(r"\s*\(.*$", "", name).strip()
        if looks_like_en_name(name):
            return name, label

    # Isnad-style English: last on(-the)-authority-of in the opening chain
    matches = list(ON_AUTH.finditer(t)) + list(ON_AUTH_SHORT.finditer(t))
    if matches:
        head = [m for m in matches if m.start() < 520] or matches
        # Prefer last non-prophet name
        for m in reversed(head):
            name = _clean_name_en(m.group(1))
            name = re.sub(r"\s*\(.*$", "", name).strip()
            if looks_like_en_name(name):
                return name, "last_on_authority"
    return None, None


def extract_ar_primary(text_ar: str, text_en: str) -> tuple[str | None, str | None]:
    chain = extract_ravi_chain(text_ar, text_en=text_en)
    for name in reversed(chain):
        cleaned = _clean_name_ar(name)
        if looks_like_ar_name(cleaned):
            return cleaned, "arabic_isnad_companion"
    return None, None


def resolve_narrator(text_en: str, text_ar: str) -> tuple[str | None, str | None, str | None]:
    """Return (name, method, language_source)."""
    name, method = extract_en_primary(text_en)
    if name:
        return name, method, "en"
    name, method = extract_ar_primary(text_ar, text_en)
    if name:
        return name, method, "ar"
    return None, None, None


def open_db() -> sqlite3.Connection:
    DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).isoformat()
    conn = open_db()

    books_out: dict = {}
    totals = Counter()
    method_totals = Counter()

    for slug in SLUGS:
        print(f"Rebuilding narrators: {slug} ...", flush=True)
        book = conn.execute("SELECT id, name_en FROM books WHERE slug=?", (slug,)).fetchone()
        if not book:
            books_out[slug] = {"error": "missing book"}
            continue

        eng = load_edition(slug, "eng")
        ara = load_edition(slug, "ara")
        print(f"  source eng={len(eng)} ara={len(ara)}", flush=True)

        rows = conn.execute(
            """
            SELECT id, hadith_number, text_ar, text_en, narrator
            FROM hadiths WHERE book_id=? ORDER BY hadith_number
            """,
            (book["id"],),
        ).fetchall()

        before_present = sum(1 for r in rows if (r["narrator"] or "").strip())
        stats = {
            "book": book["name_en"],
            "slug": slug,
            "total": len(rows),
            "before_present": before_present,
            "before_missing": len(rows) - before_present,
            "after_present": 0,
            "after_missing": 0,
            "recovered_new": 0,
            "kept_existing_same": 0,
            "replaced_with_authenticated": 0,
            "cleared_unverified": 0,
            "still_missing_unverifiable": 0,
            "methods": {},
            "samples_recovered": [],
            "samples_still_missing": [],
        }
        methods = Counter()

        for row in rows:
            n = int(row["hadith_number"])
            hid = int(row["id"])
            local = (row["narrator"] or "").strip()
            # Prefer live authenticated edition text; fall back to local DB text.
            src_en = (eng.get(n, {}).get("text") or row["text_en"] or "").strip()
            src_ar = (ara.get(n, {}).get("text") or row["text_ar"] or "").strip()

            name, method, lang = resolve_narrator(src_en, src_ar)
            if name:
                methods[f"{lang}:{method}"] += 1
                stats["after_present"] += 1
                totals["after_present"] += 1
                if not local:
                    conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", (name, hid))
                    stats["recovered_new"] += 1
                    totals["recovered_new"] += 1
                    if len(stats["samples_recovered"]) < 8:
                        stats["samples_recovered"].append(
                            {"n": n, "narrator": name, "method": f"{lang}:{method}"}
                        )
                elif local == name:
                    stats["kept_existing_same"] += 1
                    totals["kept_existing_same"] += 1
                else:
                    # Replace with authenticated extraction (never invent; overwrite unverified/mismatched)
                    conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", (name, hid))
                    stats["replaced_with_authenticated"] += 1
                    totals["replaced_with_authenticated"] += 1
            else:
                stats["after_missing"] += 1
                totals["after_missing"] += 1
                if local:
                    # Existing value could not be re-verified from authenticated editions → clear
                    conn.execute("UPDATE hadiths SET narrator=? WHERE id=?", ("", hid))
                    stats["cleared_unverified"] += 1
                    totals["cleared_unverified"] += 1
                else:
                    stats["still_missing_unverifiable"] += 1
                    totals["still_missing_unverifiable"] += 1
                if len(stats["samples_still_missing"]) < 8:
                    stats["samples_still_missing"].append(
                        {
                            "n": n,
                            "reason": "No verifiable narrator in authenticated English or Arabic isnad",
                            "en_prefix": src_en[:120],
                            "ar_prefix": src_ar[:80],
                        }
                    )

        stats["methods"] = dict(methods)
        method_totals.update(methods)
        totals["total"] += stats["total"]
        totals["before_present"] += before_present
        books_out[slug] = stats
        print(
            f"  before={before_present} after={stats['after_present']} "
            f"recovered_new={stats['recovered_new']} replaced={stats['replaced_with_authenticated']} "
            f"still_missing={stats['after_missing']}",
            flush=True,
        )

    conn.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        ("last_narrator_rebuild", generated_at),
    )
    conn.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        (
            "narrator_rebuild_note",
            "Narrators extracted only from authenticated fawazahmed0/hadith-api@1 "
            "English labels + Arabic isnad. Never AI-generated. Unverifiable left empty.",
        ),
    )
    conn.commit()
    conn.close()

    with gzip.open(GZ, "wb", compresslevel=9) as gz:
        gz.write(DB.read_bytes())
    DB.unlink(missing_ok=True)

    summary = {
        "generated_at": generated_at,
        "policy": [
            "Never invent narrator names with AI.",
            "Import only from authenticated Sunni editions (fawazahmed0/hadith-api@1).",
            "If narrator cannot be verified, leave empty.",
        ],
        "source": "fawazahmed0/hadith-api@1 (eng + ara editions)",
        "totals": {
            "total_hadith": totals["total"],
            "before_present": totals["before_present"],
            "after_present": totals["after_present"],
            "after_missing": totals["after_missing"],
            "recovered_new": totals["recovered_new"],
            "kept_existing_same": totals["kept_existing_same"],
            "replaced_with_authenticated": totals["replaced_with_authenticated"],
            "cleared_unverified": totals["cleared_unverified"],
            "still_missing_unverifiable": totals["still_missing_unverifiable"],
            "methods": dict(method_totals),
        },
        "books": books_out,
    }
    REPORT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT_MD.write_text(_md(summary), encoding="utf-8")
    print(json.dumps(summary["totals"], indent=2, ensure_ascii=False))
    print(f"Wrote {REPORT_MD}")
    return 0


def _md(summary: dict) -> str:
    t = summary["totals"]
    lines = [
        "# Narrator Rebuild Report",
        "",
        f"Generated: `{summary['generated_at']}`",
        "",
        "## Policy",
        "",
        "- Never invent narrator names with AI.",
        "- Import only from authenticated Sunni editions (`fawazahmed0/hadith-api@1`).",
        "- If a narrator cannot be verified from authenticated English or Arabic isnad, leave empty.",
        "",
        "## Exact recovery totals",
        "",
        f"| Metric | Count |",
        f"|--------|------:|",
        f"| Total Hadith | **{t['total_hadith']}** |",
        f"| Narrators present BEFORE rebuild | **{t['before_present']}** |",
        f"| Narrators present AFTER rebuild | **{t['after_present']}** |",
        f"| Narrators still missing (unverifiable) | **{t['after_missing']}** |",
        f"| **Newly recovered** | **{t['recovered_new']}** |",
        f"| Kept existing (same authenticated value) | {t['kept_existing_same']} |",
        f"| Replaced with authenticated value | {t['replaced_with_authenticated']} |",
        f"| Cleared (could not re-verify) | {t['cleared_unverified']} |",
        "",
        "### Extraction methods (authenticated text only)",
        "",
        "| Method | Count |",
        "|--------|------:|",
    ]
    for method, count in sorted(t["methods"].items(), key=lambda x: (-x[1], x[0])):
        lines.append(f"| `{method}` | {count} |")
    lines += ["", "## Per collection", ""]
    for slug, b in summary["books"].items():
        if "error" in b:
            lines += [f"### `{slug}`", "", f"ERROR: {b['error']}", ""]
            continue
        lines += [
            f"### {b['book']} (`{slug}`)",
            "",
            f"| Metric | Count |",
            f"|--------|------:|",
            f"| Total | {b['total']} |",
            f"| Before present / missing | {b['before_present']} / {b['before_missing']} |",
            f"| After present / missing | **{b['after_present']}** / **{b['after_missing']}** |",
            f"| Newly recovered | **{b['recovered_new']}** |",
            f"| Replaced with authenticated | {b['replaced_with_authenticated']} |",
            f"| Cleared unverified | {b['cleared_unverified']} |",
            "",
        ]
    lines += [
        "## Notes",
        "",
        "- “Recovered” means a narrator string was written into `hadiths.narrator` from authenticated source text.",
        "- Remaining empties are cases where the authenticated edition has no extractable narrator "
        "(empty text, “Narrator not mentioned”, chain-only comments, etc.).",
        "- Follow-up forensic CSV: `HADITH_FORENSIC_AUDIT_NARRATORS.csv`",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
