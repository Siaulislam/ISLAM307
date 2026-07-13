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

import json
import re
import sys
from pathlib import Path

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

# Find transmission markers. Optional leading "و" (واخبرني / وحدثنا).
# Bare "ان" is NOT a general TX marker (matn leak) — use _AN_* patterns instead.
_TX_FIND = re.compile(
    r"(?:^|[\s،,;:]+|(?:قال|قالت)\s*:?\s*)"
    r"و?"
    r"(?P<verb>حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن)"
    r"(?=[\s،,;:]+|$)",
    re.UNICODE,
)

# Sanad continuation: أن NAME أخبره / حدثه (optional comma before أخبره).
_AN_AKHBARAHU = re.compile(
    r"(?:^|[\s،,;:]+)"
    r"ان\s+"
    r"(?P<name>[^،,;:\n\"«»‏]{2,70}?)"
    r"\s*[،,]?\s*"
    r"(?:اخبره|حدثه|سمعه)",
    re.UNICODE,
)

# Sanad end: أن NAME قال (Companion) — not أن الحارث سأل / أن هرقل …
_AN_QALA = re.compile(
    r"(?:^|[\s،,;:]+)"
    r"ان\s+"
    r"(?P<name>[^،,;:\n\"«»‏]{2,70}?)"
    r"\s*[،,]?\s*"
    r"قال(?:\s|$|،|,)",
    re.UNICODE,
)

# Opening "قال ابن شهاب / قال أبو …" — NOT قال حدثنا / قال أخبرنا.
_QALA_NAME = re.compile(
    r"(?:^|[\s،,;:]+)"
    r"(?P<verb>قال|قالت)\s+"
    r"(?!"
    r"رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|"
    r"حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s"
    r")"
    r"(?P<name>[^،,;:\n\"«»‏]{2,80}?)"
    r"(?=\s*(?:،|,|:|و(?:اخبر|حدث|انبان)|$))",
    re.UNICODE,
)

_TRAILING_SPEECH = re.compile(r"\s+(?:قال|قالت|يقول)\s*$", re.UNICODE)

# Matn / commentary fragments — never narrator names.
_MATN_NOISE = re.compile(
    r"(?:"
    r"فترة\s*الوحى|فترة\s*الوحي|"
    r"في\s*حديثه|وهو\s*يحدث|"
    r"بينا\s*انا|بينما\s*انا|"
    r"في\s*قوله|قوله\s*تعالى|قوله\s*تعالي|"
    r"نحوه"
    r")",
    re.UNICODE,
)

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
    for verb in (*_TX_VERBS, "عن", "ان"):
        if folded == verb or folded.startswith(verb + " "):
            name = _normalize_ws(name[len(verb) :]).strip(" ،,;:.-")
            folded = _fold_ar(name)
            break

    # Cut matn / tafsir / location leftovers (not part of the person name).
    name = re.split(
        r"\s+(?:قال|قالت|يقول|يحدث|تحدث|في\s+قوله|في\s+قول|على\s+المنبر)\b",
        name,
        maxsplit=1,
    )[0]
    name = _TRAILING_SPEECH.sub("", name)
    name = re.sub(r"(?:،|\s)+في\s*$", "", name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    # Remove dangling "انه" / "انها" ONLY — never bare "ان" (breaks سفيان).
    name = re.sub(r"\s*,?\s*انه(?:ا)?\s*$", "", name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    if not name or name in {"قال", "قالت", "ان", "عن", "و", "ه", "ها", "انه", "انها", "في"}:
        return ""
    if _is_prophet_token(name):
        return ""
    if re.search(r"يحدث|تحدث", _fold_ar(name)):
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
    """Arabic isnad only — NEVER include Matn.

    Sanad continues through: حدثنا / حدثني / أخبرنا / أخبرني / أنبأنا / سمعت / عن /
    قال حدثنا / أنه سمع / أن X أخبره …

    Matn begins (STOP) at the earliest of:
    - quoted speech / في قوله تعالى / إنما …
    - قال رسول الله / سمعت رسول الله يقول / أن النبي قال / قال كان رسول الله …
    - أن <person> سأل رسول الله (questioner inside matn, e.g. الحارث)
    - أن <person> + story verb (e.g. أن هرقل أرسل)
    - بعد Companion أخبره: قال أخبرني أبو سفيان / أن أبا سفيان أخبره أن هرقل …
    - explicit matn openers (وهو يحدث، بينا أنا، …)

    Do NOT cut merely because رسول الله appears later deep in the Matn story
    without a sanad-ending speech formula near the cut point.
    """
    display = _strip_diac(text_ar)
    plain = _fold_ar(display)
    if not plain:
        return ""

    candidates: list[int] = []

    def add_cut(pos: int, min_pos: int = 8) -> None:
        if pos >= min_pos:
            candidates.append(pos)

    story_verb = (
        r"(?:ارسل|دعا|اتوه|قال\s+له|سالتك|سالته|يزعم|"
        r"في\s+ركب|وكانوا|ثم\s+دعا|فادع)"
    )

    # --- Explicit matn / commentary openings ---
    for pat in (
        r"وهو\s+يحدث",
        r"فقال\s+في\s+حديثه",
        r"قال\s+في\s+حديثه",
        r"بينا\s+انا",
        r"بينما\s+انا",
        r"يحدث\s+عن\s+فترة",
        r"بلغ\s+(?:ابا|ابي)\s+سفيان",
        r"في\s+قوله\s*تعال[ىي]",
    ):
        m = re.search(pat, plain)
        if m:
            add_cut(m.start())

    # --- Quoted matn / Quran braces ---
    for m in re.finditer(r"[\"«»\{]|قوله\s*تعال[ىي]", plain):
        add_cut(m.start(), min_pos=12)

    # --- Prophet speaking = matn (keep sanad before this phrase) ---
    for pat in (
        r"سمعت\s+رسول\s*الله",
        r"سمع\s+رسول\s*الله",
        r"قال\s+رسول\s*الله",
        r"قالت\s+رسول\s*الله",
        r"قال\s+كان\s+رسول\s*الله",
        r"كان\s+رسول\s*الله",
        r"ان\s+رسول\s*الله(?:\s+صلى\s+الله\s+عليه(?:\s+واله)?\s+وسلم)?\s+قال",
        r"ان\s+النبي(?:\s+صلى\s+الله\s+عليه(?:\s+واله)?\s+وسلم)?\s+قال",
        r"عن\s+النبي\s+(?:صلى|انه\s+قال|قال)",
        r"قال\s+النبي",
        r"سمعت\s+النبي",
    ):
        m = re.search(pat, plain)
        if m:
            add_cut(m.start())

    # --- Matn-opening verbs (+ optional فينا) before Prophet ---
    # e.g. قال قام فينا رسول الله / خرج رسول الله / خطب رسول الله
    matn_verbs = (
        r"قام|جلس|خرج|دخل|اتي|جاء|ذهب|راي|خطب|خطبنا|قرا|كتب|تكلم|دعا|"
        r"سال|سالت|سيل|سئل|اجاب|بعث|ارسل|نزل|بينا|بينما|كان|كنت|كنا|دخلنا|خرجنا"
    )
    for m in re.finditer(
        rf"(?:^|[\s،,;:])(?:{matn_verbs})"
        rf"(?:\s+فينا)?"
        rf"\s+(?:رسول\s*الله|النبي\b|نبي\s*الله)",
        plain,
    ):
        # Cut at the verb (skip leading whitespace from the non-capturing prefix)
        pos = m.start()
        while pos < len(plain) and plain[pos] in " \t،,;:":
            pos += 1
        add_cut(pos)

    # --- Companion speech that opens matn: انها قالت / انه قال (not انه سمع) ---
    for m in re.finditer(r"انها\s+قالت|انه\s+قال(?!\s+رسول)", plain):
        add_cut(m.start())

    # --- أن <person> سأل … رسول الله → matn questioner (الحارث) ---
    for m in re.finditer(
        r"\sان\s+(?!ه\s+سمع)(?!ها\s+سمعت)"
        r"[^\n]{0,80}?"
        r"(?:سال|سالت)\s+(?:رسول\s*الله|النبي)",
        plain,
    ):
        add_cut(m.start())

    # --- Immediate story subject only (هرقل / أبو سفيان / الحارث + story verb) ---
    # Do NOT match Companion sanad links like أن ابن عباس أخبره أن هرقل أرسل.
    for m in re.finditer(
        rf"\sان\s+"
        rf"(?:هرقل|ابا\s+سفيان|ابو\s+سفيان|الحارث\b)[^\n،]{{0,40}}?"
        rf"\s*[،,]?\s*{story_verb}",
        plain,
    ):
        add_cut(m.start())

    # --- أن أبا سفيان أخبره أن هرقل أرسل → whole clause matn ---
    for m in re.finditer(
        rf"(?P<matn>ان\s+(?:ابا|ابو)\s+سفيان[^\n]{{0,40}}?\s*[،,]?\s*اخبره\s+"
        rf"ان\s+[^\n]{{2,40}}?\s*[،,]?\s*{story_verb})",
        plain,
    ):
        add_cut(m.start("matn"))

    # --- After Companion أخبره: story continues (أبو سفيان / هرقل) ---
    for m in re.finditer(
        r"ان\s+(?!ابا\s+سفيان|ابو\s+سفيان|هرقل|الحارث)"
        r"[^\n]{2,70}?\s*[،,]?\s*اخبره"
        r"(?P<tail>\s+قال\s+اخبرني\s+(?:ابو|ابا)\s+سفيان"
        r"|\s+ان\s+(?:ابا|ابو)\s+سفيان"
        r"|\s+ان\s+هرقل"
        r"|\s+قال\s+ان\s+هرقل)",
        plain,
    ):
        add_cut(m.start("tail"))

    # --- قال / قالت: opens matn when followed by action verb or Prophet ---
    for m in re.finditer(
        r"قال(?:ت)?\s*:?\s*(?!حدثنا|حدثني|اخبرنا|اخبرني|سمعت|انبانا|انباني)",
        plain,
    ):
        ahead = plain[m.end() : m.end() + 60]
        if re.match(
            rf"\s*(?:(?:{matn_verbs})\b|سمعت\s+رسول|رسول\s*الله|النبي\b|"
            r"ان\s+الحارث|ان\s+ابا\s+سفيان|ان\s+هرقل|"
            r"بلغ\s+|وهو\s+|"
            r"اخبرني\s+(?:ابو|ابا)\s+سفيان)",
            ahead,
        ):
            add_cut(m.start())

    if not candidates:
        m = re.search(r"[\"«»]|سمعت\s+رسول\s*الله|قال\s+رسول\s*الله|في\s+قوله", plain)
        cut = m.start() if m else min(420, len(plain))
    else:
        cut = min(candidates)

    return display[:cut].strip(" ،,;:")


def _prepare_isnad_display(isnad: str) -> tuple[str, str]:
    """Return (display_text, search_text) with aligned offsets (1:1 folding)."""
    display = _strip_diac(isnad)
    # Normalize "أنه سمع" / "انه سمع" → سمعت (isnad continuation). Avoid \b (breaks on Arabic).
    display = re.sub(r"أن(?:ه|ها)?\s+سمع\s+|ان(?:ه|ها)?\s+سمع\s+", " سمعت ", display)
    # Bukhari parallel isnad marker "ح وحدثنا" → clean chain break.
    display = re.sub(r"\s*ح\s*و\s*(?=حدثنا|حدثني)", " . ", display)
    display = re.sub(r"،?\s*نحوه\s*", " ", display)
    search = _fold_ar(display)
    return display, search


def _is_matn_noise(name: str) -> bool:
    n = _fold_ar(name)
    if _MATN_NOISE.search(n):
        return True
    if re.search(
        r"^(?:في|وهو|فقال|بينا|بينما|فترة|حديثه|نحوه|له\s+سالتك|سالتك|قالوا|"
        r"ابو\s+سفيان|ابا\s+سفيان|هرقل|"
        r"قام|جلس|خرج|دخل|خطب|بعث|ارسل|نزل|كان|سئل)\b",
        n,
    ):
        return True
    if re.search(r"(?:سالتك|يزعم|ارسل|دعا|يزيدون|ينقصون|فزعمت|بشاشته|القريش|الشام|قام\s+فينا)", n):
        return True
    if re.search(r"^(?:هرقل|الملك|اصحابه|ملك|فينا)$", n):
        return True
    # Long multi-clause blobs (not ordinary ibn-chains).
    if len(n.split()) > 12:
        return True
    if "،" in n or "," in n:
        return True
    return False


def _extract_names_from_ar_isnad(isnad: str) -> list[str]:
    """
    Parse authenticated Arabic isnad ONLY.
    Never invent names; never take Matn phrases as rawi.
    Preserves sanad order (first transmitter → last Companion).
    """
    if not isnad:
        return []

    display, search = _prepare_isnad_display(isnad)
    found: list[tuple[int, str]] = []
    seen: set[str] = set()

    def add(raw: str, pos: int) -> bool:
        cleaned = _strip_diac(raw or "")
        cleaned = re.sub(r"،?\s*أخبر[هها]?\s*$", "", cleaned)
        cleaned = re.split(r"\s+\.\s+", cleaned)[0].strip(" ،,;:")
        cleaned = re.split(r"\s+أن\s+|\s+ان\s+", cleaned, maxsplit=1)[0].strip(" ،,;:")
        name = _clean_name_ar(cleaned)
        if not name or _is_prophet_token(name) or _is_matn_noise(name):
            return False
        key = _fold_ar(name).replace(" ", "")
        if key in seen:
            return False
        seen.add(key)
        found.append((pos, name))
        return True

    def is_story_person(folded_name: str) -> bool:
        return bool(re.search(r"^(?:ابا|ابو)\s+سفيان|هرقل|الحارث\b", folded_name))

    # 1) Leading قال / قالت <Name>
    for m in _QALA_NAME.finditer(search):
        add(display[m.start("name") : m.end("name")], m.start("name"))

    # 2) أن NAME أخبره / حدثه
    for m in _AN_AKHBARAHU.finditer(search):
        name_span = display[m.start("name") : m.end("name")]
        if is_story_person(_fold_ar(name_span)):
            continue
        after = search[m.end() : m.end() + 55]
        if re.match(r"\s*ان\s+\S+", after) and re.search(
            r"ارسل|دعا|اتوه|فقال|سالتك|يزعم|في\s+ركب|هرقل", after
        ):
            continue
        add(name_span, m.start("name"))

    # 3) أن NAME قال (Companion)
    for m in _AN_QALA.finditer(search):
        name_span = display[m.start("name") : m.end("name")]
        folded_name = _fold_ar(name_span)
        if is_story_person(folded_name) or re.search(r"سال|سالت|ارسل|دعا", folded_name):
            continue
        add(name_span, m.start("name"))

    # 3b) Trailing أن NAME at end of cut isnad (قال may be stripped by matn cut)
    for m in re.finditer(
        r"(?:^|[\s،,;:]+)ان\s+(?P<name>[^،,;:\n\"«»‏]{2,70}?)\s*$",
        search,
    ):
        name_span = display[m.start("name") : m.end("name")]
        folded_name = _fold_ar(name_span)
        if is_story_person(folded_name):
            continue
        if re.search(r"اخبار|حدث|سال|ارسل", folded_name):
            continue
        add(name_span, m.start("name"))

    # 4) Transmission verbs
    matches = list(_TX_FIND.finditer(search))
    for i, m in enumerate(matches):
        verb = m.group("verb")
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(search)
        prev = search[max(0, m.start() - 8) : m.start()]
        if verb == "عن" and re.search(r"يحدث\s*$|تحدث\s*$|نحدث\s*$", prev):
            continue

        chunk = display[start:end].strip(" ،,;:")
        if not chunk:
            continue

        folded_chunk = _fold_ar(chunk)
        if re.match(
            r"^(?:انها\s+قالت|انه\s+قال|قال\s+رسول|قالت\s+رسول|قال\s+كان|وهو\s+يحدث|فقال\s+في|"
            r"ان\s+الحارث|ان\s+هرقل|ان\s+ابا\s+سفيان|سمعت\s+رسول|بلغ\s+|في\s+قوله)",
            folded_chunk,
        ):
            break

        # Always peel nested أن … (handled by AN_* / trailing patterns)
        nested = re.search(r"\sان\s+", folded_chunk)
        if nested:
            chunk = chunk[: nested.start()].strip(" ،,;:")
            if not chunk:
                continue

        # Drop speech / parallel-chain tails before noise checks
        chunk = re.sub(r"\s*[،,]?\s*\.\s*$", "", chunk).strip(" ،,;:")
        chunk = re.sub(r"\s*[،,]?\s*(?:يقول|يحدث)\s*:?\s*$", "", chunk).strip(" ،,;:")
        # Peel companion "قال / قالت" + matn opener (قام فينا / خرج / …)
        folded_for_peel = _fold_ar(chunk)
        m_peel = re.search(
            r"[،,]?\s*قال(?:ت)?\s*:?\s*"
            r"(?=قام|جلس|خرج|دخل|اتي|جاء|خطب|بعث|ارسل|نزل|بينا|بينما|كان|"
            r"سئل|سيل|سال|سالت|رسول|النبي|بلغ|وهو)",
            folded_for_peel,
        )
        if m_peel:
            chunk = chunk[: m_peel.start()].strip(" ،,;:")
        if not chunk:
            continue

        if _is_prophet_token(chunk) or _is_matn_noise(chunk):
            # Parallel transmitters: يونس، ومعمر
            parts = re.split(r"\s*،\s*و", chunk)
            if len(parts) > 1 and all(
                p.strip() and not _is_matn_noise(p) and not _is_prophet_token(p) for p in parts
            ):
                offset = start
                for p in parts:
                    add(p, offset)
                    offset += len(p) + 1
                continue
            continue

        add(chunk, start)
        if len(found) >= 16:
            break

    found.sort(key=lambda t: t[0])
    return [name for _, name in found]


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
    book_slug: str | None = None,
) -> list[str]:
    """
    Ordered sanad names from authenticated isnad only.

    Includes رسول الله ﷺ as the final node when the Matn is Prophet
    speech/action. Compiler is never included. Matn verbs (قام فينا, …)
    are never narrators.
    """
    ar = (text_ar or "").strip()
    en = (text_en or "").strip()

    names: list[str] = []
    if ar:
        try:
            _here = Path(__file__).resolve().parent
            if str(_here) not in sys.path:
                sys.path.insert(0, str(_here))
            from isnad_engine import parse_hadith_isnad

            parsed = parse_hadith_isnad(
                ar,
                book_slug=book_slug or "bukhari",
                hadith_number=0,
            )
            names = [n for n in parsed.primary_names if n]
        except Exception:
            names = _extract_names_from_ar_isnad(_cut_isnad_ar(ar))
            # Append Prophet when matn is Prophet action/speech
            try:
                from isnad_engine.matn_guards import PROPHET_DISPLAY, should_append_prophet

                if should_append_prophet(ar) and not any(_is_prophet_token(n) for n in names):
                    names.append(PROPHET_DISPLAY)
            except Exception:
                pass

    if len(names) < 1 and en:
        names = _extract_narrated_en(en)

    if not names and primary:
        p = _clean_name_en(primary) if re.search(r"[A-Za-z]", primary or "") else _clean_name_ar(primary or "")
        if p:
            names = [p]

    # Keep Prophet ﷺ when present as final sanad node; drop empty only.
    return [n for n in names if n]


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
    """Urdu isnad excerpt (before Prophet / matn markers)."""
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


def isnad_excerpt_en(text_en: str | None, max_len: int = 320) -> str:
    """English isnad head only (Narrated …), before Prophet/matn."""
    text = (text_en or "").strip()
    if not text:
        return ""
    return _cut_isnad_en(text)[:max_len]


_UR_HONOR = re.compile(r"\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہا|عنها|عنہ|عنه)\s*", re.UNICODE)


def _clean_name_ur(raw: str) -> str:
    name = _normalize_ws(raw or "")
    name = _UR_HONOR.sub(" ", name)
    name = re.sub(r"\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہما|عنهما|عنہا|عنها|عنہ|عنه)\s*", " ", name)
    name = _normalize_ws(name).strip(" ،,;:۔")
    name = re.sub(r"\s+(نے|سے|کی|کو|ما)$", "", name).strip()
    if not name or name in {"ہم", "ان", "انہوں", "اپنے", "والد", "یہ", "اس", "حدیث", "وہ", "ما"}:
        return ""
    if _is_prophet_token(name):
        return ""
    if len(name) > 100:
        return ""
    return name


def extract_ravi_chain_urdu(text_ur: str | None) -> list[str]:
    """Urdu isnad names only (stop before Prophet; Prophet not included)."""
    head = isnad_excerpt_urdu(text_ur, max_len=560)
    if not head:
        return []

    names: list[str] = []
    seen: set[str] = set()

    def add(raw: str) -> None:
        name = _clean_name_ur(raw)
        if not name:
            return
        key = name.replace(" ", "")
        if key in seen:
            return
        seen.add(key)
        names.append(name)

    # "ابن شہاب کہتے ہیں مجھ کو ابوسلمہ … نے جابر … سے"
    for m in re.finditer(
        r"(?:^|۔|\.)\s*([^،.]{2,40}?)\s+کہتے\s+ہیں\s+مجھ\s*کو\s+([^،.]{2,60}?)\s+نے\s+([^،.]{2,70}?)\s+سے",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
        add(m.group(2))
        add(m.group(3))

    for m in re.finditer(
        r"(?:ہم\s*)?کو\s+([^،.]{2,60}?)\s+نے\s+(?:یہ\s+)?(?:حدیث\s+)?بیان\s+کی",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
    for m in re.finditer(r"ہم\s*کو\s+([^،.]{2,60}?)\s+نے\s+خبر\s+دی", head, re.UNICODE):
        add(m.group(1))
    for m in re.finditer(
        r"ان\s*کو\s+([^،.]{2,50}?)\s+نے(?:\s+([^،.]{2,50}?)\s+کی\s+روایت\s+سے)?\s*(?:خبر\s+دی|بیان\s+کی)?",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
        if m.group(2):
            add(m.group(2))
    for m in re.finditer(
        r"([^\s،,]{2,40})\s+([^\s،,]{2,40})\s+سے\s+روایت\s+کرتے",
        head,
        re.UNICODE,
    ):
        add(m.group(1))
        add(m.group(2))
    for m in re.finditer(
        r"(?:^|،|\.|۔)\s*(?:وہ\s+)?([^\s،.]{2,20}(?:\s+[^\s،.]{2,20}){0,3})\s+سے(?=\s*(?:،|۔|\.|$|وہ))",
        head,
        re.UNICODE,
    ):
        chunk = m.group(1)
        if any(tok in chunk for tok in ("نے", "بیان", "خبر", "روایت", "حدیث", "کہتے")):
            continue
        add(chunk)
    if re.search(r"اپنے\s+والد\s+سے", head):
        add("ان کے والد")
    for m in re.finditer(
        r"انہوں\s+نے\s+(?!اپنے\s+والد)([^،.]{2,70}?)\s+سے\s+نقل\s+کی",
        head,
        re.UNICODE,
    ):
        add(m.group(1))

    return [n for n in names if n and not _is_prophet_token(n)]


def extract_ravi_by_lang(
    text_ar: str | None,
    primary: str | None = None,
    text_en: str | None = None,
    text_ur: str | None = None,
    book_slug: str | None = None,
) -> dict[str, list[str]]:
    """Authenticated rawi lists keyed by language code."""
    ar = extract_ravi_chain(text_ar, primary, text_en, text_ur, book_slug=book_slug)
    ur = extract_ravi_chain_urdu(text_ur)
    en = _extract_narrated_en(text_en)
    # English editions usually expose only the companion. Prefer full Arabic
    # isnad names when English lacks a multi-person chain (never invent EN names).
    if len(en) < 2 and len(ar) >= 2:
        en = list(ar)
    elif not en:
        en = list(ar)
    if not ur:
        ur = list(ar)
    return {"ar": ar, "en": en, "ur": ur}


def isnad_by_lang(
    text_ar: str | None,
    text_en: str | None = None,
    text_ur: str | None = None,
) -> dict[str, str]:
    return {
        "ar": isnad_excerpt(text_ar),
        "en": isnad_excerpt_en(text_en),
        "ur": isnad_excerpt_urdu(text_ur),
    }


_REF_LABELS = {
    "en": {
        "kitab": "Kitab",
        "baab": "Baab",
        "volume": "Volume",
        "english_kitab": "English Kitab",
        "english_name": "English Name",
        "takhreej": "Takhreej",
        "status": "Status",
        "wazahat": "Wazahat",
    },
    "ur": {
        "kitab": "کتاب",
        "baab": "باب",
        "volume": "جلد",
        "english_kitab": "انگریزی کتاب",
        "english_name": "انگریزی نام",
        "takhreej": "تخریج",
        "status": "حیثیت",
        "wazahat": "وضاحت",
    },
    "ar": {
        "kitab": "كتاب",
        "baab": "باب",
        "volume": "المجلد",
        "english_kitab": "الكتاب بالإنجليزية",
        "english_name": "الاسم بالإنجليزية",
        "takhreej": "التخريج",
        "status": "الحالة",
        "wazahat": "الشرح",
    },
}

_I18N_PATH = Path(__file__).resolve().parent / "chapter_i18n.json"
_I18N_CACHE: dict | None = None


def _load_chapter_i18n() -> dict:
    global _I18N_CACHE
    if _I18N_CACHE is not None:
        return _I18N_CACHE
    if _I18N_PATH.exists():
        _I18N_CACHE = json.loads(_I18N_PATH.read_text(encoding="utf-8"))
    else:
        _I18N_CACHE = {"books": {}, "chapters": {}}
    return _I18N_CACHE


def _localized_chapter(book_slug: str, chapter_title: str, lang: str) -> str:
    """Return chapter/kitab title in the requested language from authenticated i18n map."""
    chapter = (chapter_title or "").strip()
    if not chapter:
        return ""
    if lang == "en":
        return chapter
    data = _load_chapter_i18n()
    entry = (data.get("chapters") or {}).get(book_slug, {}).get(chapter)
    if isinstance(entry, dict):
        value = (entry.get(lang) or "").strip()
        if value:
            return value
    return chapter


def _localized_book_name(book_slug: str, book_name_en: str, book_name_ar: str | None, lang: str) -> str:
    data = _load_chapter_i18n()
    entry = (data.get("books") or {}).get(book_slug) or {}
    if lang == "en":
        return (entry.get("en") or book_name_en or "").strip()
    if lang == "ar":
        return (entry.get("ar") or book_name_ar or book_name_en or "").strip()
    if lang == "ur":
        return (entry.get("ur") or book_name_en or "").strip()
    return book_name_en


def build_reference_detail(
    *,
    book_name: str,
    book_slug: str,
    book_name_ar: str | None = None,
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

    grade_raw = (grade or "").strip()
    chapter = (chapter_title or "").strip()
    ch_num = "" if chapter_number in (None, "") else str(chapter_number)

    def _status(lang: str) -> str:
        if grade_raw:
            return grade_raw
        if book_slug in {"bukhari", "muslim"}:
            return {"en": "Sahih", "ur": "صحیح", "ar": "صحيح"}[lang]
        return {"en": "Not graded in source", "ur": "ماخذ میں درجہ نہیں", "ar": "غير مُصنَّف في المصدر"}[lang]

    kitab_en = _localized_chapter(book_slug, chapter, "en")
    kitab_ur = _localized_chapter(book_slug, chapter, "ur")
    kitab_ar = _localized_chapter(book_slug, chapter, "ar")
    # Baab: same authenticated chapter title until per-hadith baab exists in DB.
    baab_en, baab_ur, baab_ar = kitab_en, kitab_ur, kitab_ar

    base = {
        "kitab": kitab_ur or chapter,
        "baab": baab_ur or chapter,
        "baab_number": ch_num,
        "volume": volume,
        "english_kitab": kitab_en,
        "english_name": book_name,
        "hadith_number": hadith_ref,
        "takhreej": "",
        "status": _status("ur"),
        "wazahat": "",
        "source_url": f"https://sunnah.com/{book_slug}:{hadith_number}",
        "chapter_number": ch_num,
    }

    by_lang: dict[str, dict] = {}
    for lang, labels in _REF_LABELS.items():
        if lang == "ur":
            kitab, baab = kitab_ur or chapter, baab_ur or chapter
        elif lang == "ar":
            kitab, baab = kitab_ar or chapter, baab_ar or chapter
        else:
            kitab, baab = kitab_en or chapter, baab_en or chapter

        values = {
            "kitab": kitab,
            "baab": baab,
            "volume": volume,
            "english_kitab": kitab_en,  # always English chapter title
            "english_name": book_name,  # always English book name
            "takhreej": "",
            "status": _status(lang),
            "wazahat": "",
        }
        rows = [[labels[key], values[key]] for key in labels]
        by_lang[lang] = {
            "labels": labels,
            "values": values,
            "rows": rows,
            "book_name": _localized_book_name(book_slug, book_name, book_name_ar, lang),
        }

    base["by_lang"] = by_lang
    return base

