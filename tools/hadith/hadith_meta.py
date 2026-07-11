#!/usr/bin/env python3
"""
Extract authentic isnad (rawi / narrator chain) and reference detail.

Rules:
- Narrators come ONLY from the Isnad, never from the Matn.
- Chain = first transmitter → … → last Companion before the Prophet ﷺ.
- Do NOT include Prophet Muhammad ﷺ in the rawi list.
- Preserve full names (ibn / bin / bint / Abu / Umm / al- / ibn Abi / ibn al-).
- Never invent names; parse authenticated Arabic/English source text only.
- English is used internally for "Narrated X" labels and Prophet/matn boundaries.
"""

from __future__ import annotations

import re

_DIAC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")

_PROPHET_AR = re.compile(
    r"(?:"
    r"رسول\s*الله|رسول\s*اللہ|"
    r"النبي\b|النبی\b|"
    r"نبي\s*الله|نبی\s*اللہ|"
    r"محمد\s*(?:صلى|صلی|ﷺ)"
    r")",
    re.UNICODE,
)

_PROPHET_EN = re.compile(
    r"(?:"
    r"Allah'?s\s+Messenger|"
    r"Messenger\s+of\s+Allah|"
    r"the\s+Prophet|"
    r"Prophet\s+Muhammad|"
    r"Holy\s+Prophet"
    r")",
    re.IGNORECASE,
)

_HONORIFIC_AR = re.compile(
    r"\s*(?:ـ\s*)?(?:رضي|رضى)\s*الله\s*(?:عنهما|عنها|عنهم|عنه)\s*(?:ـ\s*)?",
    re.UNICODE,
)

_HONORIFIC_EN = re.compile(
    r"\s*\((?:may\s+Allah\s+be\s+pleased[^)]*|the\s+mother\s+of\s+the\s+faithful[^)]*)\)\s*",
    re.IGNORECASE,
)

# Transmission verbs ONLY — never bare "ان" (would break سفيان / حيان).
_TX_VERBS = (
    "حدثنا",
    "حدثني",
    "اخبرنا",
    "اخبرني",
    "انبانا",
    "انباني",
    "سمعت",
)

_TX_FIND = re.compile(
    r"(?:^|[\s،,;:]+|(?:قال|قالت)\s*:?\s*)"
    r"(?P<verb>حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن)"
    r"(?=[\s،,;:]+|$)",
    re.UNICODE,
)

_TRAILING_SPEECH = re.compile(r"\s+(?:قال|قالت|يقول)\s*$", re.UNICODE)

_PROPHET_NAME_ONLY = re.compile(
    r"^(?:"
    r"رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|نبی\s*اللہ|"
    r"محمد(?:\s*صلى.*)?|"
    r"allah'?s\s+messenger|the\s+prophet|messenger\s+of\s+allah|prophet\s+muhammad"
    r")$",
    re.IGNORECASE | re.UNICODE,
)


def _strip_diac(text: str) -> str:
    """Strip tashkeel only — keep ة / ى / ئ (part of authentic names)."""
    return _DIAC.sub("", text or "")


def _fold_ar(text: str) -> str:
    """Fold hamza forms for verb / boundary matching only."""
    t = _strip_diac(text)
    return (
        t.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ؤ", "و")
        .replace("ئ", "ي")
    )


def _normalize_ws(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()


def _is_prophet_token(name: str) -> bool:
    n = _normalize_ws(_fold_ar(name))
    if not n:
        return False
    if _PROPHET_NAME_ONLY.match(n):
        return True
    if _PROPHET_AR.search(n) and len(n) < 48:
        return True
    if _PROPHET_EN.search(n) and len(n) < 56:
        return True
    return False


def _clean_name_ar(raw: str) -> str:
    """Preserve ibn/bin/bint/Abu/Umm/al-/ibn Abi; strip honorifics and matn tails."""
    name = _HONORIFIC_AR.sub(" ", raw or "")
    name = name.replace("ـ", " ")
    name = _strip_diac(name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    folded = _fold_ar(name)
    for verb in (*_TX_VERBS, "عن"):
        if folded == verb or folded.startswith(verb + " "):
            name = _normalize_ws(name[len(verb) :]).strip(" ،,;:.-")
            folded = _fold_ar(name)
            break

    # Cut matn / tafsir / location leftovers (not part of the person name).
    name = re.split(
        r"\s+(?:قال|قالت|يقول|في\s+قوله|في\s+قول|على\s+المنبر)\b",
        name,
        maxsplit=1,
    )[0]
    name = _TRAILING_SPEECH.sub("", name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    # Remove dangling "انه" / "انها" ONLY — never bare "ان" (breaks سفيان).
    name = re.sub(r"\s*,?\s*انه(?:ا)?\s*$", "", name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    if not name or name in {"قال", "قالت", "ان", "عن", "و", "ه", "ها", "انه", "انها"}:
        return ""
    if _is_prophet_token(name):
        return ""
    if len(name) > 90:
        return ""
    return name


def _clean_name_en(raw: str) -> str:
    name = _HONORIFIC_EN.sub(" ", raw or "")
    name = _normalize_ws(name).strip(" ,;:.-")
    name = re.split(
        r"\s+(?:said|reported|asked|while|that|in\s+the|regarding|reporting)\b",
        name,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    name = _normalize_ws(name).strip(" ,;:.-'\"")
    if not name or _is_prophet_token(name):
        return ""
    if len(name) > 80:
        return ""
    return name


def _cut_isnad_ar(text_ar: str) -> str:
    """Arabic isnad only: start → last narrator, before Prophet / matn.

    Returns diacritic-stripped text (hamza preserved) for name display.
    """
    display = _strip_diac(text_ar)
    plain = _fold_ar(display)
    if not plain:
        return ""

    candidates: list[int] = []

    # 1) Companion begins speaking: انها قالت / انه قال (not انه سمع)
    for m in re.finditer(r"انها\s+قالت|انه\s+قال", plain):
        candidates.append(m.start())

    # 2) ان <person> … Prophet  (matn, e.g. ان الحارث … سال رسول الله)
    for m in re.finditer(r"\sان\s+(?!ه\s+سمع)", plain):
        if _PROPHET_AR.search(plain[m.start() :]):
            if re.search(r"(?:حدثنا|حدثني|اخبرنا|عن)", plain[: m.start()]):
                candidates.append(m.start())

    # 3) Direct report from the Prophet
    for m in re.finditer(
        r"(?:قال|قالت|سمعت|سمع|عن|ان|كان|سال)\s+(?:رسول\s*الله|النبي|نبي\s*الله)",
        plain,
    ):
        candidates.append(m.start())

    # 4) First prophet token after a chain exists
    for m in _PROPHET_AR.finditer(plain):
        if re.search(r"(?:حدثنا|حدثني|اخبرنا|عن)", plain[: m.start()]):
            candidates.append(m.start())
            break

    if not candidates:
        m = re.search(r"[\"«»\{]|قوله\s*تعالي", plain)
        cut = m.start() if m else min(500, len(plain))
    else:
        positive = [c for c in candidates if c > 0]
        cut = min(positive) if positive else min(candidates)

    # Offsets align between display and plain (1:1 folding).
    return display[:cut].strip(" ،,;:")


def _prepare_isnad_display(isnad: str) -> tuple[str, str]:
    """Return (display_text, search_text) with aligned offsets (1:1 folding)."""
    display = _strip_diac(isnad)
    # Normalize "أنه سمع" / "انه سمع" → سمعت (isnad continuation). Avoid \b (breaks on Arabic).
    display = re.sub(r"أن(?:ه|ها)?\s+سمع\s+|ان(?:ه|ها)?\s+سمع\s+", " سمعت ", display)
    search = _fold_ar(display)
    return display, search


def _extract_names_from_ar_isnad(isnad: str) -> list[str]:
    """
    English-shaped internal parse of Arabic isnad:
      حدثنا / أخبرنا / عن / سمعت + FULL NAME
    Names are sliced from diacritic-stripped authentic text (keeps ئ/ة).
    """
    if not isnad:
        return []

    display, search = _prepare_isnad_display(isnad)
    matches = list(_TX_FIND.finditer(search))
    if not matches:
        return []

    names: list[str] = []
    seen: set[str] = set()

    for i, m in enumerate(matches):
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(search)
        chunk = display[start:end].strip(" ،,;:")
        if not chunk:
            continue

        folded_chunk = _fold_ar(chunk)
        if re.match(r"^(?:انها\s+قالت|انه\s+قال|قال\s+رسول|قالت\s+رسول)", folded_chunk):
            break
        if _is_prophet_token(chunk):
            break

        name = _clean_name_ar(chunk)
        if not name:
            continue
        if _is_prophet_token(name):
            break

        key = _fold_ar(name).replace(" ", "")
        if key in seen:
            continue
        seen.add(key)
        names.append(name)
        if len(names) >= 16:
            break

    return names


def _cut_isnad_en(text_en: str) -> str:
    plain = text_en or ""
    m = _PROPHET_EN.search(plain)
    if not m:
        return plain[:400]
    return plain[: m.start()].strip(" ,;:")


def _extract_narrated_en(text_en: str | None) -> list[str]:
    """English 'Narrated X:' companion label when Arabic isnad is unavailable."""
    text = (text_en or "").strip()
    if not text:
        return []
    head = _cut_isnad_en(text) if _PROPHET_EN.search(text) else text.split(".", 1)[0]
    m = re.match(
        r"^\s*Narrated\s+(.+?)(?:\s*[:.\n]|\s+that\b|\s+said\b|\s+reported\b)",
        head,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not m:
        return []
    name = _clean_name_en(m.group(1))
    return [name] if name else []


def extract_ravi_chain(
    text_ar: str | None,
    primary: str | None = None,
    text_en: str | None = None,
    text_ur: str | None = None,  # noqa: ARG001 — display helper only
) -> list[str]:
    """
    Ordered rawi list from authenticated isnad only (excludes Prophet ﷺ).

    Prefer Arabic isnad; fall back to English Narrated-X; then DB narrator field.
    """
    ar = (text_ar or "").strip()
    en = (text_en or "").strip()

    names: list[str] = []
    if ar:
        names = _extract_names_from_ar_isnad(_cut_isnad_ar(ar))

    if len(names) < 1 and en:
        names = _extract_narrated_en(en)

    if not names and primary:
        p = _clean_name_en(primary) if re.search(r"[A-Za-z]", primary or "") else _clean_name_ar(primary or "")
        if p and not _is_prophet_token(p):
            names = [p]

    return [n for n in names if n and not _is_prophet_token(n)]


def isnad_excerpt(text_ar: str | None, max_len: int = 480) -> str:
    """Authenticated Arabic isnad head (before Prophet/matn)."""
    text = (text_ar or "").strip()
    if not text:
        return ""
    plain = _fold_ar(text)
    cut_plain = _cut_isnad_ar(text)
    if not cut_plain or not plain:
        return text[:max_len]
    ratio = len(cut_plain) / max(len(plain), 1)
    cut = max(1, min(len(text), int(len(text) * ratio) + 12))
    return text[:cut].strip(" ،,;:")[:max_len]


def isnad_excerpt_urdu(text_ur: str | None, max_len: int = 480) -> str:
    """Urdu isnad excerpt for display only (names are not parsed from Urdu)."""
    text = (text_ur or "").strip()
    if not text:
        return ""
    stop = re.search(
        r"(آپ\s+نے\s+فرمایا|فرمایا\s+کہ|"
        r"نبی\s+کریم|رسول\s+اللہ|رسول\s+الله|"
        r"صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال)",
        text,
    )
    head = text[: stop.start()].strip(" ،,") if stop else text[:max_len]
    return head[:max_len]


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
