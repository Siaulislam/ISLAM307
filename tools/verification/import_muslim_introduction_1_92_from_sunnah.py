#!/usr/bin/env python3
"""Import Sahih Muslim Introduction narrations from sunnah.com (exact copy).

Source: https://sunnah.com/muslim/introduction (cached markdown via r.jina.ai)

Rules (per product owner):
  - Copy Arabic + English exactly from sunnah.com; never invent or paraphrase.
  - Keep preface rows hadith_number -1 and 0 untouched.
  - Map In-book Narration 1..91 -> hadith_number 1..91.
  - Sahih Muslim 4a / 4b -> display as Introduction, Narration 4A / 4B
    (sunnah lists 4b as Narration 5; we still label it 4B as requested).
  - Import sunnah In-book Narrations 1–91. Slot 92 may hold user-provided
    باب صحة الاحتجاج بالحديث المعنعن prose (do not clear if already filled).
  - Copy Subject (باب) headings; each subject covers until the next subject.
  - Preserve existing text_ur on each row.
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
CACHE = ROOT / "tools" / "verification" / "cache" / "sunnah_pages"
CACHE_MD = CACHE / "muslim_introduction_index.md"
META_OUT = ROOT / "data" / "source" / "muslim_introduction_1_92_meta.json"
REPORT_JSON = ROOT / "reports" / "verification" / "MUSLIM_INTRODUCTION_1_92_IMPORT.json"
REPORT_MD = ROOT / "reports" / "verification" / "MUSLIM_INTRODUCTION_1_92_IMPORT.md"
PREVIEW_GZ = ROOT / "preview" / "library" / "data" / "hadith" / "muslim.json.gz"

AR_RE = re.compile(r"[\u0600-\u06FF]")
BOOK_ID = 2
CHAPTER_ID = 99  # Introduction


def fetch_intro_md() -> str:
    CACHE.mkdir(parents=True, exist_ok=True)
    if CACHE_MD.exists() and CACHE_MD.stat().st_size > 10_000:
        return CACHE_MD.read_text(encoding="utf-8")
    url = "https://r.jina.ai/https://sunnah.com/muslim/introduction"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 ISLAM307-muslim-intro/1.0",
            "Accept": "text/markdown",
            "X-Return-Format": "markdown",
        },
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        body = resp.read().decode("utf-8", "replace")
    CACHE_MD.write_text(body, encoding="utf-8")
    return body


def unwrap_md_links(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = text.replace("\u00a0", " ")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def is_mostly_arabic(text: str) -> bool:
    if not text or not AR_RE.search(text):
        return False
    ar = len(AR_RE.findall(text))
    latin = len(re.findall(r"[A-Za-z]", text))
    return ar >= 20 and ar >= latin


def parse_hadiths(md: str) -> list[dict]:
    """Parse numbered hadith blocks + chapter subjects from the intro page."""
    # Cut footer noise
    cut = md.find("Hadith Text-")
    if cut > 0:
        md = md[:cut]

    # Find chapter markers: English Chapter line + following باب line
    chapters: list[tuple[int, str, str]] = []
    for m in re.finditer(
        r"Chapter:\s*(.+)\n+(?:\(\d+[A-Z]?\)\n+)?\s*(باب[^\n]*|اب[^\n]*)",
        md,
    ):
        en = m.group(1).strip()
        ar = m.group(2).strip()
        ar = ar.replace("\u200f", "").strip()
        if ar.startswith("اب ") and not ar.startswith("باب"):
            ar = "ب" + ar  # fix truncated باب in markdown
        chapters.append((m.start(), en, ar))

    ref_pat = re.compile(
        r"\*\*Reference\*\*:\[([^\]]+)\]\(([^)]+)\)\nIn-book reference:Introduction, Narration\s+(\S+)",
        re.M,
    )
    matches = list(ref_pat.finditer(md))
    hadiths: list[dict] = []

    for i, m in enumerate(matches):
        ref_label = m.group(1).strip()
        ref_url = m.group(2).strip()
        narr = m.group(3).strip()
        block_end = m.start()
        block_start = matches[i - 1].end() if i else 0
        # Prefer content after previous block's trailing chrome
        chunk = md[block_start:block_end]

        # Subject in force at this block start
        subj_en, subj_ar = "", ""
        for pos, en, ar in chapters:
            if pos < block_end:
                subj_en, subj_ar = en, ar
            else:
                break

        # Title line like "Sahih Muslim 4 a" or "Sahih Muslim Introduction 92"
        title_m = None
        for tm in re.finditer(
            r"(?m)^Sahih Muslim(?: Introduction)?\s+([0-9]+(?:\s*[ab])?)\s*$",
            chunk,
        ):
            title_m = tm
        if not title_m:
            # fallback: last occurrence before reference in full md slice
            title_m = re.search(
                r"(?m)^Sahih Muslim(?: Introduction)?\s+([0-9]+(?:\s*[ab])?)\s*$",
                chunk,
            )
        body = chunk[title_m.end() :] if title_m else chunk
        body = re.sub(r"(?m)^\[\]\([^)]*\)\s*$", "", body)
        body = re.sub(r"(?m)^Report Error.*$", "", body)
        body = body.strip()

        # Split English vs Arabic paragraphs
        paras = [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]
        en_parts: list[str] = []
        ar_parts: list[str] = []
        for p in paras:
            # skip leftover chapter headings accidentally included
            if p.startswith("Chapter:") or p.startswith("باب") or re.match(r"^\(\d+[A-Z]?\)$", p):
                continue
            if p.startswith("اب ") and len(AR_RE.findall(p)) > 10 and len(re.findall(r"[A-Za-z]", p)) < 5:
                continue
            plain = unwrap_md_links(p)
            if is_mostly_arabic(plain):
                ar_parts.append(plain)
            else:
                # English (or mixed intro lines that are not Arabic hadith)
                if AR_RE.search(plain) and len(AR_RE.findall(plain)) > len(re.findall(r"[A-Za-z]", plain)):
                    ar_parts.append(plain)
                else:
                    en_parts.append(plain)

        text_en = "\n\n".join(en_parts).strip()
        text_ar = "\n\n".join(ar_parts).strip()

        # Label number + variant
        label_raw = ""
        variant = ""
        lm = re.search(r"(?:Introduction\s+)?(\d+)\s*([ab])?\s*$", ref_label, re.I)
        if lm:
            label_raw = lm.group(1)
            variant = (lm.group(2) or "").lower()
        elif title_m:
            tm2 = re.match(r"(\d+)\s*([ab])?", title_m.group(1).strip(), re.I)
            if tm2:
                label_raw = tm2.group(1)
                variant = (tm2.group(2) or "").lower()

        narr_num = int(re.sub(r"\D", "", narr) or "0")
        # User rule: 4a/4b -> Narration 4A / 4B
        if variant == "a":
            display_narr = "4A"
            tracking = "Introduction, Narration 4A"
        elif variant == "b":
            display_narr = "4B"
            tracking = "Introduction, Narration 4B"
        else:
            display_narr = str(narr_num)
            tracking = f"Introduction, Narration {narr_num}"

        hadiths.append(
            {
                "hadith_number": narr_num,  # DB slot = in-book narration
                "narration": narr_num,
                "display_narration": display_narr,
                "tracking_reference": tracking,
                "ref_label": ref_label,
                "ref_url": ref_url,
                "label_number": int(label_raw) if label_raw.isdigit() else narr_num,
                "variant": variant,
                "subject_en": subj_en,
                "subject_ar": subj_ar,
                "text_en": text_en,
                "text_ar": text_ar,
            }
        )

    return hadiths


def open_db() -> sqlite3.Connection:
    if not DB.exists() or DB.stat().st_size < 1_000_000:
        DB.write_bytes(gzip.decompress(GZ.read_bytes()))
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def apply_to_db(conn: sqlite3.Connection, hadiths: list[dict]) -> dict:
    updated = []
    skipped = []
    assert len(hadiths) == 91, f"expected 91 sunnah narrations, got {len(hadiths)}"
    assert hadiths[0]["hadith_number"] == 1
    assert hadiths[-1]["hadith_number"] == 91
    assert hadiths[-1]["label_number"] == 92

    for h in hadiths:
        n = h["hadith_number"]
        row = conn.execute(
            "SELECT id, text_ar, text_en, text_ur, source_provider FROM hadiths WHERE book_id=? AND hadith_number=?",
            (BOOK_ID, n),
        ).fetchone()
        if not row:
            skipped.append({"n": n, "reason": "missing_row"})
            continue
        meta = {
            "src": "sunnah.com/muslim/introduction",
            "tracking_reference": h["tracking_reference"],
            "display_narration": h["display_narration"],
            "ref_label": h["ref_label"],
            "subject_ar": h["subject_ar"],
            "subject_en": h["subject_en"],
            "label_number": h["label_number"],
            "variant": h["variant"],
        }
        conn.execute(
            """
            UPDATE hadiths
            SET text_ar = ?, text_en = ?, reference_url = ?, source_provider = ?, chapter_id = ?
            WHERE book_id = ? AND hadith_number = ?
            """,
            (
                h["text_ar"],
                h["text_en"],
                h["ref_url"],
                "sunnah-intro-meta:" + json.dumps(meta, ensure_ascii=False, separators=(",", ":")),
                CHAPTER_ID,
                BOOK_ID,
                n,
            ),
        )
        updated.append(
            {
                "hadith_number": n,
                "tracking_reference": h["tracking_reference"],
                "ar_len": len(h["text_ar"]),
                "en_len": len(h["text_en"]),
                "subject_ar": h["subject_ar"][:80],
                "ref_label": h["ref_label"],
            }
        )

    # Slot 92: keep user-provided mu'an'an chapter if already filled; otherwise leave empty.
    row92 = conn.execute(
        "SELECT id, length(trim(coalesce(text_ar,''))) AS ar_len, source_provider FROM hadiths WHERE book_id=? AND hadith_number=92",
        (BOOK_ID,),
    ).fetchone()
    preserved_92 = bool(row92 and int(row92["ar_len"] or 0) > 0)

    # Sanity: preface untouched
    for pref in (-1, 0):
        p = conn.execute(
            "SELECT source_provider, length(text_ar) FROM hadiths WHERE book_id=? AND hadith_number=?",
            (BOOK_ID, pref),
        ).fetchone()
        if not p or not str(p["source_provider"] or "").startswith("user-provided"):
            raise RuntimeError(f"preface hadith {pref} was altered or missing")

    conn.commit()
    return {"updated": updated, "skipped": skipped, "preserved_92": preserved_92}


def patch_preview_pack(hadiths: list[dict]) -> None:
    """Rebuild muslim preview pack fields for intro rows from DB + meta."""
    if not PREVIEW_GZ.exists():
        return
    with gzip.open(PREVIEW_GZ, "rt", encoding="utf-8") as f:
        pack = json.load(f)

    by_n = {h["hadith_number"]: h for h in hadiths}
    conn = open_db()
    rows = {
        int(r["hadith_number"]): r
        for r in conn.execute(
            "SELECT hadith_number, text_ar, text_en, text_ur, source_provider, reference_url FROM hadiths WHERE book_id=? AND hadith_number BETWEEN -1 AND 92",
            (BOOK_ID,),
        )
    }
    conn.close()

    for item in pack.get("hadiths", []):
        n = item.get("n")
        if n is None or not (-1 <= int(n) <= 92):
            continue
        n = int(n)
        db = rows.get(n)
        if not db:
            continue
        item["ar"] = db["text_ar"] or ""
        item["en"] = db["text_en"] or ""
        # keep ur from DB
        item["ur"] = db["text_ur"] or item.get("ur") or ""

        meta = {}
        sp = db["source_provider"] or ""
        if sp.startswith("sunnah-intro-meta:"):
            try:
                meta = json.loads(sp[len("sunnah-intro-meta:") :])
            except json.JSONDecodeError:
                meta = {}

        rd = item.get("reference_detail") or {}
        if n == -1:
            item["reference"] = "Sahih Muslim · Introduction (preface)"
            baab = "المقدمة"
            item["reference_detail"] = _set_baab(rd, baab, baab_en="Introduction", hadith_disp="preface")
        elif n == 0:
            baab = "باب وُجُوبِ الرِّوَايَةِ عَنِ الثِّقَاتِ، وَتَرْكِ الْكَذَّابِينَ"
            item["reference"] = f"Sahih Muslim · {baab}"
            item["reference_detail"] = _set_baab(
                rd,
                baab,
                baab_en="The Obligation of Transmitting on Authority of Trustworthy Narrators and Abandoning the Liars",
                hadith_disp="0",
            )
        elif n in by_n:
            h = by_n[n]
            baab = h["subject_ar"] or meta.get("subject_ar") or "المقدمة"
            baab_en = h["subject_en"] or meta.get("subject_en") or "Introduction"
            disp = h["display_narration"]
            item["reference"] = h["tracking_reference"]
            item["display_n"] = disp
            item["reference_detail"] = _set_baab(rd, baab, baab_en=baab_en, hadith_disp=str(disp))
        elif n == 92:
            # Prefer DB content (may be user-provided باب صحة الاحتجاج بالحديث المعنعن).
            item["ar"] = db["text_ar"] or ""
            item["en"] = db["text_en"] or ""
            item["ur"] = db["text_ur"] or item.get("ur") or ""
            baab = meta.get("subject_ar") or "باب صِحَّةِ الاِحْتِجَاجِ بِالْحَدِيثِ الْمُعَنْعَنِ"
            baab_en = meta.get("subject_en") or "The Soundness of Relying on Ḥadīth Related with the Term Meaning 'On Authority of'"
            if item["ar"] or item["en"]:
                item["reference"] = meta.get("tracking_reference") or "Introduction, Narration 92"
                item["display_n"] = meta.get("display_narration") or "92"
                item["reference_detail"] = _set_baab(rd, baab, baab_en=baab_en, hadith_disp="92")
            else:
                item["reference"] = "Introduction (no Narration 92 on sunnah.com)"
                item["reference_detail"] = _set_baab(rd, "المقدمة", baab_en="Introduction", hadith_disp="92")

    with gzip.open(PREVIEW_GZ, "wt", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, separators=(",", ":"))


def _set_baab(rd: dict, baab_ar: str, baab_en: str, hadith_disp: str) -> dict:
    out = dict(rd) if rd else {}
    out["baab"] = baab_ar
    out["english_kitab"] = baab_en
    out["hadith_number"] = hadith_disp
    by = dict(out.get("by_lang") or {})
    for lang in ("ar", "ur", "en"):
        entry = dict(by.get(lang) or {})
        values = dict(entry.get("values") or {})
        if lang == "en":
            values["baab"] = baab_en
            values["kitab"] = baab_en
        else:
            values["baab"] = baab_ar
            # keep kitab as مقدمة localization if present
            values.setdefault("kitab", baab_ar if lang == "ar" else "مقدمہ")
        values["english_kitab"] = baab_en
        entry["values"] = values
        # refresh rows if present
        labels = entry.get("labels") or {}
        if labels:
            entry["rows"] = [[labels[k], values.get(k, "")] for k in labels]
        by[lang] = entry
    out["by_lang"] = by
    return out


def gzip_db() -> None:
    # checkpoint WAL if any
    conn = sqlite3.connect(DB)
    conn.execute("PRAGMA wal_checkpoint(FULL)")
    conn.close()
    data = DB.read_bytes()
    with gzip.open(GZ, "wb", compresslevel=9) as f:
        f.write(data)


def main() -> None:
    md = fetch_intro_md()
    hadiths = parse_hadiths(md)
    META_OUT.parent.mkdir(parents=True, exist_ok=True)
    META_OUT.write_text(json.dumps(hadiths, ensure_ascii=False, indent=2), encoding="utf-8")

    conn = open_db()
    result = apply_to_db(conn, hadiths)
    conn.close()
    gzip_db()
    patch_preview_pack(hadiths)

    # validation samples
    samples = []
    for n in (1, 4, 5, 6, 14, 25, 32, 91):
        h = next(x for x in hadiths if x["hadith_number"] == n)
        samples.append(
            {
                "n": n,
                "tracking": h["tracking_reference"],
                "subject": h["subject_ar"][:60],
                "en_start": h["text_en"][:80],
                "ar_start": h["text_ar"][:60],
            }
        )

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "https://sunnah.com/muslim/introduction",
        "count_parsed": len(hadiths),
        "updated": len(result["updated"]),
        "skipped": result["skipped"],
        "cleared_92": result["cleared_92"],
        "preface_preserved": [-1, 0],
        "mapping_note": "DB hadith_number = sunnah In-book Narration (1..91). 4a->4A, 4b->4B. Introduction 92 is Narration 91.",
        "samples": samples,
        "subjects": sorted(
            {
                (h["subject_ar"], h["subject_en"], h["hadith_number"])
                for h in hadiths
            },
            key=lambda t: t[2],
        ),
    }
    # unique subject ranges
    ranges = []
    cur = None
    for h in hadiths:
        key = (h["subject_ar"], h["subject_en"])
        if cur is None or cur["key"] != key:
            if cur:
                ranges.append({"subject_ar": cur["key"][0], "subject_en": cur["key"][1], "from": cur["from"], "to": cur["to"]})
            cur = {"key": key, "from": h["hadith_number"], "to": h["hadith_number"]}
        else:
            cur["to"] = h["hadith_number"]
    if cur:
        ranges.append({"subject_ar": cur["key"][0], "subject_en": cur["key"][1], "from": cur["from"], "to": cur["to"]})
    report["subject_ranges"] = ranges

    REPORT_JSON.parent.mkdir(parents=True, exist_ok=True)
    REPORT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# Sahih Muslim Introduction 1–92 import from sunnah.com",
        "",
        f"- Parsed: **{len(hadiths)}** narrations (In-book 1–91; last label Introduction 92)",
        f"- Updated DB rows: **{len(result['updated'])}**",
        "- Preserved preface: hadith **-1**, **0**",
        "- Cleared AR/EN on hadith **92** (no Narration 92 on sunnah; content ends at Narration 91 / Introduction 92)",
        "- 4a / 4b stored as Narration **4A** (slot 4) and **4B** (slot 5)",
        "",
        "## Subject ranges",
        "",
    ]
    for r in ranges:
        lines.append(f"- **{r['from']}–{r['to']}**: {r['subject_ar']}")
        lines.append(f"  - EN: {r['subject_en']}")
    lines.append("")
    REPORT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({"ok": True, "parsed": len(hadiths), "updated": len(result["updated"]), "ranges": ranges}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
