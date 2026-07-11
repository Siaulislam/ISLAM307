#!/usr/bin/env python3
"""Helpers to extract authentic isnad (ravi chain) and reference detail from hadith rows."""

from __future__ import annotations

import re

_DIAC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED]")

_PROPHET_AR = "رسول اللہ صلی اللہ علیہ وسلم"
_PROPHET_UR = "نبی کریم محمد صلی اللہ علیہ وسلم"

# Verbs / connectors that introduce the next narrator in an isnad (diacritics stripped).
_AR_SPLIT = re.compile(
    r"(?:^|[\s،,;:]+)"
    r"(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)"
    r"(?:[\s،,;:]+|$)",
    re.UNICODE,
)

_AR_STOP = re.compile(
    r"(قال\s+رسول|ان\s+رسول|عن\s+النبي|انه\s+قال|يقول\s*:|سمعت\s+رسول)",
    re.UNICODE,
)

_UR_STOP = re.compile(
    r"(آپ\s+نے\s+فرمایا|فرمایا\s+کہ|کہ\s+ایک\s+شخص|سے\s+سوال\s+کیا|"
    r"نبی\s+کریم\s+صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال|"
    r"رسول\s+اللہ\s+صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال)",
    re.UNICODE,
)

_UR_HONORIFIC = re.compile(
    r"\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہا|عنها|عنہ|عنه)\s*",
    re.UNICODE,
)


def _strip_diac(text: str) -> str:
    text = _DIAC.sub("", text or "")
    return text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")


_LEADING_VERB = re.compile(
    r"^(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)\s+",
)


def _clean_ar_name(name: str) -> str:
    name = _strip_diac(name or "")
    name = re.sub(r"\s+", " ", name).strip(" ۔،,;:.-ـ")
    name = _LEADING_VERB.sub("", name)
    name = re.sub(r"^(ال)?(شيوخ|شيخ|الامام)\s+", "", name)
    name = re.sub(r"\s*(رضي الله عنه|رضي الله عنها|رضى الله عنه|رضى الله عنها).*$", "", name)
    name = re.sub(r"\s*ـ\s*$", "", name)
    return name.strip()


def _clean_ur_name(name: str) -> str:
    name = re.sub(r"\s+", " ", name or "").strip(" ،,;:۔")
    name = _UR_HONORIFIC.sub(" ", name)
    name = re.sub(r"\s+", " ", name).strip(" ،,;:۔")
    name = re.sub(r"\s+(نے|سے|کی|کو|وہ|کہتے|ہیں)$", "", name).strip()
    return name.strip()


def _append_prophet(names: list[str], label: str) -> list[str]:
    if not names:
        return names
    joined = " ".join(names)
    if "رسول اللہ" in joined or "نبی کریم" in joined or "محمد صلی" in joined:
        return names
    out = list(names)
    out.append(label)
    return out


def extract_ravi_chain_urdu(text_ur: str | None) -> tuple[list[str], str]:
    """Parse Urdu isnad (blue-highlight style) into ordered narrator names + isnad excerpt."""
    text = (text_ur or "").strip()
    if not text:
        return [], ""

    stop = _UR_STOP.search(text)
    head = text[: stop.start()].strip(" ،,") if stop else text[:560]
    if not head:
        return [], ""

    names: list[str] = []
    seen: set[str] = set()

    def add(raw: str) -> None:
        name = _clean_ur_name(raw)
        if len(name) < 2 or len(name) > 100:
            return
        if name in {"ہم", "ان", "انہوں", "اپنے", "والد", "یہ", "اس", "حدیث", "وہ"}:
            return
        key = name.replace(" ", "")
        if key in seen:
            return
        seen.add(key)
        names.append(name)

    # (ہم) کو NAME نے (یہ) حدیث بیان کی
    for m in re.finditer(
        r"(?:ہم\s*)?کو\s+([^،.]{2,60}?)\s+نے\s+(?:یہ\s+)?(?:حدیث\s+)?بیان\s+کی",
        head,
        re.UNICODE,
    ):
        add(m.group(1))

    # ہم کو NAME نے خبر دی
    for m in re.finditer(
        r"ہم\s*کو\s+([^،.]{2,60}?)\s+نے\s+خبر\s+دی",
        head,
        re.UNICODE,
    ):
        add(m.group(1))

    # ان کو NAME نے [NAME2 کی روایت سے] خبر دی
    for m in re.finditer(
        r"ان\s*کو\s+([^،.]{2,50}?)\s+نے(?:\s+([^،.]{2,50}?)\s+کی\s+روایت\s+سے)?\s*(?:خبر\s+دی|بیان\s+کی)?",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
        if m.group(2):
            add(m.group(2))

    # NAME1 NAME2 سے روایت کرتے ہیں
    for m in re.finditer(
        r"([^\s،,]{2,40})\s+([^\s،,]{2,40})\s+سے\s+روایت\s+کرتے",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
        add(m.group(2))

    # Short "وہ NAME سے" / "عقیل ابن شہاب سے" clauses only (avoid swallowing sentences)
    for m in re.finditer(
        r"(?:^|،|\.|۔)\s*(?:وہ\s+)?([^\s،.]{2,20}(?:\s+[^\s،.]{2,20}){0,3})\s+سے(?=\s*(?:،|۔|\.|$|وہ))",
        head,
        re.UNICODE,
    ):
        chunk = m.group(1)
        if any(tok in chunk for tok in ("نے", "بیان", "خبر", "روایت", "حدیث", "کہتے")):
            continue
        add(chunk)

    # انہوں نے اپنے والد سے نقل کی → keep wording from source
    if re.search(r"اپنے\s+والد\s+سے", head):
        add("ان کے والد")

    # انہوں نے NAME سے نقل کی
    for m in re.finditer(
        r"انہوں\s+نے\s+(?!اپنے\s+والد)([^،.]{2,70}?)\s+سے\s+نقل\s+کی",
        head,
        re.UNICODE,
    ):
        add(m.group(1))

    names = _append_prophet(names, _PROPHET_UR)
    return names, head[:480]


def extract_ravi_chain_arabic(text_ar: str | None, primary: str | None = None) -> tuple[list[str], str]:
    names: list[str] = []
    seen: set[str] = set()

    def add(raw: str) -> None:
        name = _clean_ar_name(raw)
        if len(name) < 2 or len(name) > 90:
            return
        if name in {"قال", "قالت", "يقول", "سمعت", "عنه", "عنها", "ابي", "ابيه"}:
            return
        # reject matn leftovers / quotes
        if any(ch in name for ch in {'"', "«", "»", "\u200f", "ما انا", "فأخذني", "يكتب"}):
            return
        if re.search(r"[A-Za-z]{3,}", name) and "bin" not in name.lower() and "ibn" not in name.lower():
            # allow English primary later; skip English matn fragments here
            if "'" in name or "(" in name:
                return
        key = name.replace(" ", "")
        if key in seen:
            return
        seen.add(key)
        names.append(name)

    text = _strip_diac(text_ar or "")
    excerpt = ""
    if text:
        stop = _AR_STOP.search(text)
        head = text[: stop.start()] if stop else text[:420]
        excerpt = isnad_excerpt(text_ar)
        for part in [p for p in _AR_SPLIT.split(head) if p and p.strip()]:
            chunk = re.split(r"(?:قال|انه|يقول|،|,)", part, maxsplit=1)[0]
            add(chunk)
            if len(names) >= 12:
                break

    primary_clean = (primary or "").strip()
    if primary_clean and len(names) < 8:
        pk = _clean_ar_name(primary_clean).replace(" ", "")
        if pk and pk not in seen and primary_clean not in names:
            # only add short primary narrator labels
            if len(primary_clean) < 60 and "(" not in primary_clean:
                names.append(primary_clean)

    names = _append_prophet(names, _PROPHET_AR)
    return names, excerpt


def extract_ravi_chain(
    text_ar: str | None,
    primary: str | None = None,
    text_en: str | None = None,
    text_ur: str | None = None,
) -> list[str]:
    """Prefer Urdu isnad (matches app screenshots), else Arabic, else primary narrator."""
    ur_names, _ = extract_ravi_chain_urdu(text_ur)
    # Urdu isnad is preferred when it yields a real chain (2+ including prophet => 1+ narrators)
    if len([n for n in ur_names if "نبی کریم" not in n and "رسول اللہ" not in n]) >= 2:
        return ur_names

    ar_names, _ = extract_ravi_chain_arabic(text_ar, primary)
    if len([n for n in ar_names if "رسول اللہ" not in n]) >= 2:
        return ar_names

    if ur_names:
        return ur_names
    if ar_names:
        return ar_names

    primary_clean = (primary or "").strip()
    if primary_clean:
        return _append_prophet([primary_clean], _PROPHET_UR)
    return []


def isnad_excerpt(text_ar: str | None, max_len: int = 420) -> str:
    """Return the authenticated Arabic isnad head (before matn), if present."""
    text = (text_ar or "").strip()
    if not text:
        return ""
    plain = _strip_diac(text)
    stop = _AR_STOP.search(plain)
    if stop:
        cut = min(len(text), max(stop.start() + 8, int(len(text) * (stop.start() / max(len(plain), 1)))))
        excerpt = text[:cut].strip(" ،,;:")
        return excerpt[:max_len]
    return text[:max_len]


def isnad_excerpt_urdu(text_ur: str | None, max_len: int = 480) -> str:
    _, excerpt = extract_ravi_chain_urdu(text_ur)
    return excerpt[:max_len]


def build_reference_detail(
    *,
    book_name: str,
    book_slug: str,
    hadith_number: int,
    reference_book,
    reference_hadith,
    chapter_title: str | None,
    chapter_number,
    grade: str | None,
) -> dict:
    """Full reference table fields matching the Reference screenshot layout."""
    volume = "" if reference_book in (None, 0, "0", "") else str(reference_book)
    hadith_ref = "" if reference_hadith in (None, "") else str(reference_hadith)
    if not hadith_ref:
        hadith_ref = str(hadith_number)

    status = (grade or "").strip()
    if not status and book_slug in {"bukhari", "muslim"}:
        status = "صحیح"

    chapter = (chapter_title or "").strip()
    ch_num = "" if chapter_number in (None, "") else str(chapter_number)
    # Baab = subject/paragraph within kitab; source DB stores chapter title.
    # Keep both fields; empty when source has no separate baab title.
    baab = chapter
    if ch_num and chapter:
        baab = f"{chapter}"

    return {
        "kitab": chapter,
        "baab": baab,
        "baab_number": ch_num,
        "volume": volume,
        "english_kitab": chapter,
        "english_name": book_name,
        "hadith_number": hadith_ref,
        "takhreej": "",
        "status": status,
        "wazahat": "",
        "source_url": f"https://sunnah.com/{book_slug}:{hadith_number}",
        "chapter_number": ch_num,
    }
