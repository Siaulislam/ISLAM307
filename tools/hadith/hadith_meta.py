#!/usr/bin/env python3
"""Helpers to extract authentic isnad (ravi chain) and reference detail from hadith rows."""

from __future__ import annotations

import re

_DIAC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED]")

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

_EN_SPLIT = re.compile(
    r"(?:^|[\s,;:]+)"
    r"(?:Narrated|narrated|From|from|on the authority of|"
    r"reported|Reported|told us|Told us|informed us|Informed us)"
    r"(?:[\s,;:]+|$)",
)


def _strip_diac(text: str) -> str:
    text = _DIAC.sub("", text or "")
    # normalize hamza / alif variants for matching (keep ة/ى for readable names)
    return text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")


_LEADING_VERB = re.compile(
    r"^(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)\s+",
)


def _clean_name(name: str) -> str:
    name = _strip_diac(name or "")
    name = re.sub(r"\s+", " ", name).strip(" ۔،,;:.-ـ")
    name = _LEADING_VERB.sub("", name)
    name = re.sub(r"^(ال)?(شيوخ|شيخ|الامام)\s+", "", name)
    name = re.sub(r"\s*(رضي الله عنه|رضي الله عنها|رضى الله عنه|رضى الله عنها).*$", "", name)
    name = re.sub(r"\s*ـ\s*$", "", name)
    return name.strip()


def extract_ravi_chain(
    text_ar: str | None,
    primary: str | None = None,
    text_en: str | None = None,
) -> list[str]:
    """Extract narrator names from authenticated Arabic (or English) isnad text."""
    names: list[str] = []
    seen: set[str] = set()

    def _add(raw: str) -> None:
        name = _clean_name(raw)
        if len(name) < 2 or len(name) > 90:
            return
        if name in {"قال", "قالت", "يقول", "سمعت", "عنه", "عنها", "ابي", "ابيه"}:
            return
        key = name.replace(" ", "")
        if key in seen:
            return
        seen.add(key)
        names.append(name)

    text = _strip_diac(text_ar or "")
    if text:
        stop = _AR_STOP.search(text)
        head = text[: stop.start()] if stop else text[:520]
        parts = [p for p in _AR_SPLIT.split(head) if p and p.strip()]
        for part in parts:
            chunk = re.split(r"(?:قال|انه|يقول|،|,)", part, maxsplit=1)[0]
            # also drop trailing "رضي..." remnants already handled in clean
            _add(chunk)
            if len(names) >= 14:
                break

    if not names and text_en:
        # fallback: light English isnad parse from authenticated English text only
        en_head = (text_en or "")[:320]
        for part in _EN_SPLIT.split(en_head):
            chunk = re.split(r"(?:that|said|reported|,)", part, maxsplit=1)[0]
            _add(chunk)
            if len(names) >= 8:
                break

    primary_clean = (primary or "").strip()
    if primary_clean:
        pk = _clean_name(primary_clean).replace(" ", "")
        # Prefer keeping the authenticated English primary narrator label as-is
        # when it is not already represented in the Arabic chain.
        if pk and pk not in seen and primary_clean not in names:
            names.append(primary_clean)

    return names


def isnad_excerpt(text_ar: str | None, max_len: int = 420) -> str:
    """Return the authenticated Arabic isnad head (before matn), if present."""
    text = (text_ar or "").strip()
    if not text:
        return ""
    plain = _strip_diac(text)
    stop = _AR_STOP.search(plain)
    if stop:
        # map approximate cut on original by length ratio
        cut = min(len(text), max(stop.start() + 8, int(len(text) * (stop.start() / max(len(plain), 1)))))
        excerpt = text[:cut].strip(" ،,;:")
        return excerpt[:max_len]
    return text[: max_len]


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
    """Full reference table fields (empty string when not present in source)."""
    volume = "" if reference_book in (None, 0, "0", "") else str(reference_book)
    hadith_ref = "" if reference_hadith in (None, "") else str(reference_hadith)
    if not hadith_ref:
        hadith_ref = str(hadith_number)

    status = (grade or "").strip()
    if not status and book_slug in {"bukhari", "muslim"}:
        status = "صحیح"

    chapter = (chapter_title or "").strip()
    ch_num = "" if chapter_number in (None, "") else str(chapter_number)

    return {
        "kitab": chapter,
        "baab": chapter,
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
