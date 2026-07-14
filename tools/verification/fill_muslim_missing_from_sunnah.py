#!/usr/bin/env python3
"""Fill missing Sahih Muslim AR/EN/subject from sunnah.com; Urdu from English.

Policy (no AI invented hadith text):
  - Arabic + English + باب copied from sunnah.com only.
  - Prefer in-book URL: https://sunnah.com/muslim/{reference_book}/{reference_hadith}
  - Else lettered reference from arabic_number (e.g. 977.03 -> muslim:977c).
  - Urdu: translate authenticated English with GoogleTranslator (same pipeline as Introduction).
  - Do not invent Arabic/English. Do not overwrite existing Arabic script.
  - Rows that are empty in both our DB and fawaz 7563 gaps (no refs) cannot be mapped
    to sunnah USC-MSA numbers safely; they are reported as source_gaps.
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

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[2]
GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
DB = ROOT / "app" / "assets" / "databases" / "hadith.db"
PREVIEW = ROOT / "preview" / "library" / "data" / "hadith" / "muslim.json.gz"
CACHE = ROOT / "tools" / "verification" / "cache" / "sunnah_pages"
OUT_DIR = ROOT / "reports" / "verification"
REPORT_JSON = OUT_DIR / "MUSLIM_SUNNAH_MISSING_FILL.json"
REPORT_MD = OUT_DIR / "MUSLIM_SUNNAH_MISSING_FILL.md"

AR_RE = re.compile(r"[\u0600-\u06FF]")
DIAC = re.compile(r"[\u064B-\u065F\u0670\u0640]")
VARIANT_LETTER = {1: "a", 2: "b", 3: "c", 4: "d", 5: "e", 6: "f", 7: "g", 8: "h"}


def has_arabic(text: str | None) -> bool:
    return bool(text and AR_RE.search(text))


def has_text(text: str | None) -> bool:
    return bool((text or "").strip())


def open_db() -> sqlite3.Connection:
    if not DB.exists() or DB.stat().st_size < 1_000_000:
        DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def fetch_md(path_or_ref: str) -> str:
    """path_or_ref like 'muslim/36/81' or 'muslim:977c'."""
    CACHE.mkdir(parents=True, exist_ok=True)
    safe = path_or_ref.replace("/", "_").replace(":", "_")
    cpath = CACHE / f"{safe}.md"
    if cpath.exists() and cpath.stat().st_size > 400:
        return cpath.read_text(encoding="utf-8")
    url = f"https://sunnah.com/{path_or_ref}"
    jurl = "https://r.jina.ai/" + url
    req = urllib.request.Request(
        jurl,
        headers={
            "User-Agent": "Mozilla/5.0 ISLAM307-muslim-fill/1.0",
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
            time.sleep(0.45)
            return body
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(1.3 * (attempt + 1))
    raise RuntimeError(f"fetch failed {path_or_ref}: {last_err}")


def arabic_number_to_ref(arabic_number: str | float | None) -> str | None:
    if arabic_number is None or str(arabic_number).strip() == "":
        return None
    raw = str(arabic_number).strip()
    try:
        base = int(float(raw))
    except ValueError:
        return None
    if "." in raw:
        frac = raw.split(".", 1)[1]
        # 03 -> variant index 3 -> 'c'
        try:
            idx = int(frac)
        except ValueError:
            idx = 1
        letter = VARIANT_LETTER.get(idx, "a")
        return f"{base}{letter}"
    return str(base)


def parse_sunnah_page(md: str) -> dict:
    if "returned error 404" in md.lower():
        return {"ok": False, "reason": "sunnah_404"}
    # Prefer the hadith block near Reference
    ref_m = re.search(r"\*\*Reference\*\*\s*:?\s*\[?Sahih Muslim\s+([0-9]+[a-z]*)\]?", md, re.I)
    if not ref_m:
        ref_m = re.search(r"Sahih Muslim\s+([0-9]+[a-z]*)\b", md)
    if not ref_m:
        return {"ok": False, "reason": "missing_reference"}

    # Subject / باب
    subject_ar = ""
    subject_en = ""
    bab = re.search(r"(باب[^\n]+)", md)
    if bab:
        subject_ar = re.sub(r"\s+", " ", bab.group(1)).strip()
    ch = re.search(r"Chapter:\s*([^\n]+)", md)
    if ch:
        subject_en = ch.group(1).strip()

    # Split around reference for hadith body
    ref_pos = md.find("**Reference**")
    if ref_pos < 0:
        ref_pos = md.find("Reference")
    before = md[:ref_pos] if ref_pos > 0 else md

    # Arabic candidate: last long Arabic paragraph before reference
    paras = re.split(r"\n\s*\n", before)
    ar_cands: list[str] = []
    en_cands: list[str] = []
    for p in paras:
        plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", p)
        plain = re.sub(r"\s+", " ", plain).strip()
        if not plain or plain.startswith("##") or plain.startswith("Quotes"):
            continue
        ar_count = len(AR_RE.findall(plain))
        if ar_count >= 40:
            if plain.startswith("باب") and "حَدَّث" not in plain and "حدث" not in plain and ar_count < 150:
                continue
            ar_cands.append(plain)
        elif ar_count < 5 and len(plain) > 60:
            low = plain.lower()
            if any(
                x in low
                for x in (
                    "narrated",
                    "reported",
                    "messenger",
                    "allah",
                    "ﷺ",
                    "on the authority",
                    "heard",
                )
            ):
                if "select collections" in low or "wildcard" in low:
                    continue
                en_cands.append(plain)

    if not ar_cands:
        return {"ok": False, "reason": "no_arabic", "ref": ref_m.group(1)}
    text_ar = ar_cands[-1]
    text_en = en_cands[-1] if en_cands else ""
    # Sometimes English is immediately above Arabic as multiple short paras — join trailing EN paras
    if not text_en and en_cands:
        text_en = "\n\n".join(en_cands[-3:])
    if not text_en:
        # fallback: lines between chapter and arabic
        return {
            "ok": False,
            "reason": "no_english",
            "ref": ref_m.group(1),
            "text_ar": text_ar,
            "subject_ar": subject_ar,
            "subject_en": subject_en,
        }

    return {
        "ok": True,
        "ref": ref_m.group(1),
        "text_ar": text_ar,
        "text_en": text_en,
        "subject_ar": subject_ar,
        "subject_en": subject_en,
    }


def translate_en_to_ur(text: str) -> str:
    translator = GoogleTranslator(source="en", target="ur")
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if not paras:
        paras = [text.strip()]
    out: list[str] = []
    for p in paras:
        chunks: list[str] = []
        if len(p) <= 4000:
            chunks = [p]
        else:
            parts = re.split(r"(?<=[.!?])\s+", p)
            buf = ""
            for part in parts:
                if len(buf) + len(part) + 1 <= 4000:
                    buf = (buf + " " + part).strip()
                else:
                    if buf:
                        chunks.append(buf)
                    buf = part
            if buf:
                chunks.append(buf)
        translated_chunks: list[str] = []
        for ch in chunks:
            for attempt in range(5):
                try:
                    translated_chunks.append(translator.translate(ch))
                    break
                except Exception:
                    time.sleep(1.2 * (attempt + 1))
            else:
                raise RuntimeError("urdu translation failed")
            time.sleep(0.12)
        out.append("\n".join(translated_chunks))
    return "\n\n".join(out)


def sunnah_paths_for_row(row: sqlite3.Row) -> list[str]:
    paths: list[str] = []
    rb = row["reference_book"]
    rh = row["reference_hadith"]
    if rb not in (None, 0) and rh not in (None, 0):
        paths.append(f"muslim/{int(rb)}/{int(rh)}")
    ref = arabic_number_to_ref(row["arabic_number"])
    if ref:
        paths.append(f"muslim:{ref}")
        # also bare number
        base = re.sub(r"[a-z]+$", "", ref)
        if base != ref:
            paths.append(f"muslim:{base}")
    return list(dict.fromkeys(paths))  # unique preserve order


def update_preview_pack(updates: dict[int, dict]) -> None:
    if not PREVIEW.exists() or not updates:
        return
    with gzip.open(PREVIEW, "rt", encoding="utf-8") as f:
        pack = json.load(f)
    for item in pack.get("hadiths", []):
        n = item.get("n")
        if n is None or int(n) not in updates:
            continue
        u = updates[int(n)]
        if u.get("text_ar"):
            item["ar"] = u["text_ar"]
        if u.get("text_en"):
            item["en"] = u["text_en"]
        if u.get("text_ur"):
            item["ur"] = u["text_ur"]
        rd = item.get("reference_detail") or {}
        if u.get("subject_ar"):
            rd["baab"] = u["subject_ar"]
            by = rd.get("by_lang") or {}
            for lang in ("ar", "ur", "en"):
                entry = dict(by.get(lang) or {})
                values = dict(entry.get("values") or {})
                if lang == "en":
                    values["baab"] = u.get("subject_en") or values.get("baab") or ""
                else:
                    values["baab"] = u["subject_ar"]
                entry["values"] = values
                labels = entry.get("labels") or {}
                if labels:
                    entry["rows"] = [[labels[k], values.get(k, "")] for k in labels]
                by[lang] = entry
            rd["by_lang"] = by
            if u.get("subject_en"):
                rd["english_kitab"] = u["subject_en"]
            item["reference_detail"] = rd
    with gzip.open(PREVIEW, "wt", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, separators=(",", ":"))


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = open_db()

    incomplete = []
    for r in conn.execute(
        "SELECT id, hadith_number, text_ar, text_en, text_ur, reference_book, reference_hadith, arabic_number, chapter_id, source_provider "
        "FROM hadiths WHERE book_id=2 ORDER BY hadith_number"
    ):
        miss_ar = not has_arabic(r["text_ar"])
        miss_en = not has_text(r["text_en"])
        miss_ur = not has_text(r["text_ur"])
        if miss_ar or miss_en or miss_ur:
            incomplete.append(r)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "policy": [
            "Arabic/English/باب from sunnah.com only",
            "Urdu translated from authenticated English only",
            "No AI-invented hadith text",
            "Unmapped 7563 gap rows without sunnah refs left unchanged",
        ],
        "incomplete_before": len(incomplete),
        "filled_ar_en": [],
        "filled_ur": [],
        "skipped": [],
        "errors": [],
        "source_gaps": [],
    }
    preview_updates: dict[int, dict] = {}

    # Pass 1: fill AR/EN/subject from sunnah for missing AR or EN
    for i, row in enumerate(incomplete, 1):
        n = int(row["hadith_number"])
        need_ar = not has_arabic(row["text_ar"])
        need_en = not has_text(row["text_en"])
        if not (need_ar or need_en):
            continue
        paths = sunnah_paths_for_row(row)
        if not paths:
            report["source_gaps"].append(
                {
                    "n": n,
                    "reason": "no_sunnah_mapping_ref_or_arabic_number",
                    "has_ur": has_text(row["text_ur"]),
                }
            )
            continue
        print(f"[AR/EN {i}/{len(incomplete)}] hadith {n} <- {paths[0]}")
        parsed = None
        used = None
        for path in paths:
            try:
                md = fetch_md(path)
                parsed = parse_sunnah_page(md)
                used = path
                if parsed.get("ok") or parsed.get("text_ar"):
                    break
            except Exception as e:  # noqa: BLE001
                report["errors"].append({"n": n, "path": path, "reason": str(e)})
                parsed = None
        if not parsed or not parsed.get("text_ar"):
            report["skipped"].append(
                {
                    "n": n,
                    "reason": (parsed or {}).get("reason", "fetch_failed"),
                    "paths": paths,
                }
            )
            continue
        if need_en and not parsed.get("text_en"):
            report["skipped"].append({"n": n, "reason": "no_english_on_sunnah", "path": used})
            # still allow AR-only fill below if needed

        new_ar = parsed["text_ar"] if need_ar else row["text_ar"]
        new_en = parsed["text_en"] if (need_en and parsed.get("text_en")) else row["text_en"]
        if need_ar and not has_arabic(new_ar):
            report["skipped"].append({"n": n, "reason": "parsed_ar_invalid", "path": used})
            continue

        meta = {
            "src": f"sunnah.com/{used}",
            "ref_label": f"Sahih Muslim {parsed.get('ref')}",
            "subject_ar": parsed.get("subject_ar") or "",
            "subject_en": parsed.get("subject_en") or "",
            "filled": "ar_en_from_sunnah",
        }
        sp = "sunnah-fill-meta:" + json.dumps(meta, ensure_ascii=False, separators=(",", ":"))
        conn.execute(
            "UPDATE hadiths SET text_ar=?, text_en=?, source_provider=? WHERE id=?",
            (new_ar or "", new_en or "", sp, row["id"]),
        )
        # FTS if present
        try:
            conn.execute(
                "UPDATE hadith_fts SET text_ar=?, text_en=? WHERE hadith_id=? AND book_slug='muslim'",
                (new_ar or "", new_en or "", row["id"]),
            )
        except sqlite3.Error:
            pass

        report["filled_ar_en"].append(
            {
                "n": n,
                "path": used,
                "ref": parsed.get("ref"),
                "subject_ar": parsed.get("subject_ar"),
                "ar_len": len(new_ar or ""),
                "en_len": len(new_en or ""),
            }
        )
        preview_updates[n] = {
            "text_ar": new_ar,
            "text_en": new_en,
            "subject_ar": parsed.get("subject_ar"),
            "subject_en": parsed.get("subject_en"),
        }

    conn.commit()

    # Pass 2: fill missing Urdu from English (including newly filled EN)
    rows = list(
        conn.execute(
            "SELECT id, hadith_number, text_ar, text_en, text_ur FROM hadiths WHERE book_id=2 ORDER BY hadith_number"
        )
    )
    ur_targets = [
        r
        for r in rows
        if not has_text(r["text_ur"]) and has_text(r["text_en"]) and has_arabic(r["text_ar"])
    ]
    print(f"Urdu targets: {len(ur_targets)}")
    for i, row in enumerate(ur_targets, 1):
        n = int(row["hadith_number"])
        print(f"[UR {i}/{len(ur_targets)}] hadith {n}")
        try:
            ur = translate_en_to_ur(row["text_en"])
            conn.execute("UPDATE hadiths SET text_ur=? WHERE id=?", (ur, row["id"]))
            try:
                conn.execute(
                    "UPDATE hadith_fts SET text_ur=? WHERE hadith_id=? AND book_slug='muslim'",
                    (ur, row["id"]),
                )
            except sqlite3.Error:
                pass
            report["filled_ur"].append({"n": n, "ur_len": len(ur)})
            preview_updates.setdefault(n, {})["text_ur"] = ur
            if row["text_en"] and "text_en" not in preview_updates.get(n, {}):
                preview_updates[n]["text_en"] = row["text_en"]
            if row["text_ar"] and "text_ar" not in preview_updates.get(n, {}):
                preview_updates[n]["text_ar"] = row["text_ar"]
        except Exception as e:  # noqa: BLE001
            report["errors"].append({"n": n, "reason": f"urdu_translate: {e}"})

    conn.commit()
    conn.execute("PRAGMA wal_checkpoint(FULL)")
    conn.close()

    GZ.write_bytes(gzip.compress(DB.read_bytes(), compresslevel=9))
    update_preview_pack(preview_updates)

    # Recount
    conn = open_db()
    miss_ar = miss_en = miss_ur = complete = 0
    remaining = []
    for r in conn.execute("SELECT hadith_number, text_ar, text_en, text_ur FROM hadiths WHERE book_id=2"):
        a = has_arabic(r["text_ar"])
        e = has_text(r["text_en"])
        u = has_text(r["text_ur"])
        if a and e and u:
            complete += 1
        else:
            remaining.append(
                {
                    "n": int(r["hadith_number"]),
                    "miss_ar": not a,
                    "miss_en": not e,
                    "miss_ur": not u,
                }
            )
            if not a:
                miss_ar += 1
            if not e:
                miss_en += 1
            if not u:
                miss_ur += 1
    conn.close()

    report["filled_ar_en_count"] = len(report["filled_ar_en"])
    report["filled_ur_count"] = len(report["filled_ur"])
    report["skipped_count"] = len(report["skipped"])
    report["source_gap_count"] = len(report["source_gaps"])
    report["error_count"] = len(report["errors"])
    report["after"] = {
        "complete": complete,
        "incomplete": len(remaining),
        "missing_arabic": miss_ar,
        "missing_english": miss_en,
        "missing_urdu": miss_ur,
    }
    report["remaining"] = remaining

    REPORT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Sahih Muslim missing fill from sunnah.com",
        "",
        f"- Generated: `{report['generated_at']}`",
        f"- Incomplete before: **{report['incomplete_before']}**",
        f"- Filled AR/EN from sunnah.com: **{report['filled_ar_en_count']}**",
        f"- Filled Urdu from English: **{report['filled_ur_count']}**",
        f"- Source gaps (no sunnah mapping): **{report['source_gap_count']}**",
        f"- Skipped: **{report['skipped_count']}**",
        f"- Errors: **{report['error_count']}**",
        "",
        "## After",
        "",
        f"- Complete AR+EN+UR: **{complete}**",
        f"- Incomplete: **{len(remaining)}**",
        f"- Missing Arabic: **{miss_ar}**",
        f"- Missing English: **{miss_en}**",
        f"- Missing Urdu: **{miss_ur}**",
        "",
        "## Filled AR/EN",
        "",
    ]
    for row in report["filled_ar_en"]:
        lines.append(f"- `{row['n']}` ← `{row['path']}` (Sahih Muslim {row.get('ref')})")
    lines += ["", "## Filled Urdu", ""]
    for row in report["filled_ur"]:
        lines.append(f"- `{row['n']}`")
    lines += ["", "## Source gaps (empty in 7563 scheme / no ref)", ""]
    gap_nums = [g["n"] for g in report["source_gaps"]]
    lines.append(", ".join(str(x) for x in gap_nums) if gap_nums else "—")
    REPORT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(report["after"], indent=2))
    print("filled_ar_en", report["filled_ar_en_count"], "filled_ur", report["filled_ur_count"], "gaps", report["source_gap_count"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
