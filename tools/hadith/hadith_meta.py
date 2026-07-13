#!/usr/bin/env python3
"""
Extract authentic isnad (rawi / narrator chain) and reference detail.

Rules:
- Narrators = every personal name from the start of the Arabic text until the
  first mention of the Prophet ﷺ.
- Stop immediately at the first of:
    النبي صلى الله عليه وسلم / رسول الله صلى الله عليه وسلم / محمد صلى الله عليه وسلم
    (and common orthographic / ﷺ variants).
- Do NOT include Prophet Muhammad ﷺ in the rawi list.
- Everything after that marker is Matn — never treated as narrators.
- Capture the full dynamic chain (no fixed narrator count).
- Preserve full names (ibn / bin / bint / Abu / Umm / al- / ibn Abi / ibn al-).
- Never invent names; parse authenticated Arabic/English source text only.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

_DIAC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")

# Boundary marker: first mention of the Prophet ﷺ (not bare اسم "محمد" alone).
_PROPHET_AR = re.compile(
    r"(?:"
    r"رسول\s*الله\s*(?:صلى|صلی|ﷺ)?"
    r"|رسول\s*اللہ\s*(?:صلى|صلی|ﷺ)?"
    r"|النبي\s*(?:صلى|صلی|ﷺ)?"
    r"|النبی\s*(?:صلى|صلی|ﷺ)?"
    r"|نبي\s*الله\s*(?:صلى|صلی|ﷺ)?"
    r"|نبی\s*اللہ\s*(?:صلى|صلی|ﷺ)?"
    r"|محمد\s*(?:صلى|صلی|ﷺ)"
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
_TX_FIND = re.compile(
    r"(?:^|[\s،,;:]+|(?:قال|قالت)\s*:?\s*)"
    r"و?"
    r"(?P<verb>حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن|ان)"
    r"(?=[\s،,;:]+|$)",
    re.UNICODE,
)

# Opening "قال ابن شهاب / قالت أسماء / قال أبو …" — NOT قال حدثنا / قال أخبرنا.
# Name ends at punctuation, next transmission verb, عن, or end of isnad.
_QALA_NAME = re.compile(
    r"(?:^|[\s،,;:]+)"
    r"(?P<verb>قال|قالت)\s+"
    r"(?!"
    r"رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|"
    r"حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s"
    r")"
    r"(?P<name>[^،,;:\n\"«»‏]{2,80}?)"
    r"(?=\s*(?:"
    r"،|,|:|"
    r"و?(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت)|"
    r"عن\b|"
    r"و(?:اخبر|حدث|انبان)|"
    r"$"
    r"))",
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

# Whole-token prophet titles only. Bare "محمد" is a common narrator short-name
# (e.g. محمد بن سيرين) and must NOT stop the chain.
_PROPHET_NAME_ONLY = re.compile(
    r"^(?:"
    r"رسول\s*الله(?:\s*صلى.*)?"
    r"|رسول\s*اللہ(?:\s*صلى.*)?"
    r"|النبي(?:\s*صلى.*)?"
    r"|النبی(?:\s*صلى.*)?"
    r"|نبي\s*الله(?:\s*صلى.*)?"
    r"|نبی\s*اللہ(?:\s*صلى.*)?"
    r"|محمد\s*(?:صلى|صلی|ﷺ).*"
    r"|allah'?s\s+messenger|the\s+prophet|messenger\s+of\s+allah|prophet\s+muhammad"
    r")$",
    re.IGNORECASE | re.UNICODE,
)

# Clear matn openings after a companion "قال …" (not person names).
_MATN_AFTER_QALA = re.compile(
    r"^(?:"
    r"تخلف|بينما|بينا|كان|كنت|كنا|ذكر|ذكرت|خطب|جاء|جاءت|بعث|كتب|"
    r"يسروا|تسموا|حفظت|اقبلت|بت\s|ضمني|عقلت|اتي|اتيت|سئل|سال|"
    r"ان\s+رسول|ان\s+النبي|سمعت\s+النبي|سمعت\s+رسول"
    r")",
    re.UNICODE,
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


# Transmission / connector tokens that are NEVER part of a narrator name.
_CONNECTOR_TOKENS = (
    "عن",
    "قال",
    "قالت",
    "قالا",
    "قالوا",
    "يقول",
    "يقولون",
    "تقول",
    "ذكر",
    "ذكرت",
    "حدثنا",
    "حدثني",
    "اخبرنا",
    "اخبرني",
    "انبانا",
    "انباني",
    "سمعت",
    "سمع",
    "نا",
    "ثم",
    "ان",
    "فان",
    "انه",
    "انها",
    "انهما",
    "انهم",
)


def _clean_name_ar(raw: str) -> str:
    """Preserve ibn/bin/bint/Abu/Umm/al-/ibn Abi; strip connectors and matn tails.

    Transmission words (عن، قال، قالت، حدثنا، …) are never part of a name.
    """
    name = _HONORIFIC_AR.sub(" ", raw or "")
    name = name.replace("ـ", " ")
    name = _strip_diac(name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    # Iteratively strip leading/trailing connector tokens.
    connectors = set(_CONNECTOR_TOKENS)
    for _ in range(8):
        folded = _fold_ar(name)
        tokens = folded.split()
        if not tokens:
            return ""
        changed = False
        # Leading connector
        if tokens[0] in connectors:
            # Drop the matching leading word from display name (same token count).
            parts = name.split()
            name = _normalize_ws(" ".join(parts[1:])).strip(" ،,;:.-")
            changed = True
            continue
        # Trailing connector
        if tokens[-1] in connectors:
            parts = name.split()
            name = _normalize_ws(" ".join(parts[:-1])).strip(" ،,;:.-")
            changed = True
            continue
        # Leading multi-word verbs already covered; also strip "و" + connector
        if tokens[0] == "و" and len(tokens) > 1 and tokens[1] in connectors:
            parts = name.split()
            name = _normalize_ws(" ".join(parts[2:])).strip(" ،,;:.-")
            changed = True
            continue
        if not changed:
            break

    # Cut at first internal speech/matn verb (keep the person name before it).
    folded_full = _fold_ar(name)
    m_cut = re.search(
        r"\s+(?:قال|قالت|قالا|قالوا|يقول|يقولون|تقول|يحدث|تحدث|ذكر|ذكرت|"
        r"في\s+قوله|في\s+قول|على\s+المنبر)\b",
        folded_full,
    )
    if m_cut:
        name = name[: m_cut.start()]

    name = _TRAILING_SPEECH.sub("", name)
    name = re.sub(r"(?:،|\s)+في\s*$", "", name)
    # Strip trailing "أخبره / أخبرها"
    name = re.sub(r"\s+(?:أخبره|أخبرها|أخبرهما|اخبره|اخبرها|اخبرهما)\s*$", "", name)
    name = _normalize_ws(name).strip(" ،,;:.-")

    # Final pass: reject pure connectors
    folded = _fold_ar(name)
    if not name or folded in connectors or folded in {
        "و",
        "ه",
        "ها",
        "في",
        "اخبره",
        "أخبره",
    }:
        return ""
    if _is_prophet_token(name):
        return ""
    if re.search(r"يحدث|تحدث", folded):
        return ""
    # Name must not still contain a connector token as a standalone word.
    if any(tok in connectors for tok in folded.split()):
        # Remove any remaining connector words inside (should be rare).
        kept = [p for p, f in zip(name.split(), folded.split()) if f not in connectors]
        name = _normalize_ws(" ".join(kept))
        folded = _fold_ar(name)
        if not name or folded in connectors:
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
    """Arabic isnad only: start → last narrator, immediately before Prophet ﷺ.

    Primary stop: first النبي / رسول الله / محمد صلى الله عليه وسلم (or ﷺ).
    Secondary stop: clear companion matn speech (قال كان / بينما / …) that begins
    before the Prophet marker — still excludes Matn from the narrator list.
    """
    display = _strip_diac(text_ar)
    plain = _fold_ar(display)
    if not plain:
        return ""

    candidates: list[int] = []

    # 1) Primary: first Prophet ﷺ marker (user rule).
    m = _PROPHET_AR.search(plain)
    if m:
        candidates.append(m.start())

    # 2) Companion matn speech after isnad (before / without waiting for Prophet).
    #    Never cut on "قال حدثنا / قال أخبرنا / قال سمعت".
    for m2 in re.finditer(
        r"(?:^|[\s،,;:])(?P<qala>قال(?:ت)?)\s+"
        r"(?!حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s)"
        r"(?=كان|كنت|كنا|بينما|بينا|تخلف|ذكر|خطب|جاء|جاءت|بعث|كتب|"
        r"يسروا|تسموا|حفظت|اقبلت|ضمني|عقلت|اتي|اتيت|سئل)",
        plain,
    ):
        if re.search(r"(?:حدثنا|حدثني|اخبرنا|عن)", plain[: m2.start()]):
            candidates.append(m2.start("qala"))

    # 3) Fallback matn openers when neither above matched early enough
    if not candidates:
        for pat in (
            r"وهو\s+يحدث",
            r"بينا\s+انا",
            r"بينما\s+انا",
            r"[\"«»\{]|قوله\s*تعالي|قوله\s*تعالى",
        ):
            m3 = re.search(pat, plain)
            if m3 and m3.start() > 20:
                candidates.append(m3.start())
                break

    if not candidates:
        cut = min(len(plain), 800)
    else:
        cut = min(c for c in candidates if c >= 0)

    return display[:cut].strip(" ،,;:")


def _prepare_isnad_display(isnad: str) -> tuple[str, str]:
    """Return (display_text, search_text) with aligned offsets (1:1 folding)."""
    display = _strip_diac(isnad)
    # Normalize "أنه سمع" / "انه سمع" → سمعت (isnad continuation).
    display = re.sub(r"أن(?:ه|ها)?\s+سمع\s+|ان(?:ه|ها)?\s+سمع\s+", " سمعت ", display)
    # Bukhari parallel isnad marker "ح وحدثنا" → chain break (keep authentic names).
    display = re.sub(r"\s*ح\s*و\s*(?=حدثنا|حدثني)", " . ", display)
    # Drop "نحوه" (commentary pointer, not a person).
    display = re.sub(r"،?\s*نحوه\s*", " ", display)
    search = _fold_ar(display)
    return display, search


def _is_matn_noise(name: str) -> bool:
    n = _fold_ar(name)
    if _MATN_NOISE.search(n):
        return True
    if re.search(r"^(?:في|وهو|فقال|بينا|بينما|فترة|حديثه|نحوه|تخلف|ذكر)\b", n):
        return True
    if _MATN_AFTER_QALA.match(n):
        return True
    return False


def _looks_like_person_name(name: str) -> bool:
    """Reject clear matn / verb phrases mistaken for names."""
    n = _fold_ar(name)
    if not n or _is_matn_noise(n):
        return False
    if _MATN_AFTER_QALA.match(n):
        return False
    # Too long to be a single person name.
    if len(n) > 70 or len(n.split()) > 12:
        return False
    # Reject commentary / speech crumbs.
    if re.search(
        r"(?:يمنعني|يزعم|تمارى|البعوث|في\s+المسجد|عدو\s+الله|خطيبا|"
        r"^قال\s|^قلت\s|^قيل\s|^ح$|^حدث$|^انه$|^انها$|^رجلا$|^سئل$|^اشهد|"
        r"^رايت$|^استيقظ$|^صلى\s|^لما\s|^احدثكم|"
        r"صحبت\s|فلم\s+اسمعه|كذب\s|لعمرو|لابن|"
        r"اخواننا|يشغلهم|يلزم\s+رسول|بذلك|كان\s+يلزم)",
        n,
    ):
        return False
    # Reject if name still contains matn verb "كان/كنت" mid-phrase.
    if re.search(r"\sكان\s|\sكنت\s|\sكنا\s", n):
        return False
    tokens = [
        t
        for t in re.findall(r"\w+", n)
        if t not in _TX_VERBS and t not in {"عن", "ان", "قال", "قالت", "ح"}
    ]
    if not tokens:
        return False
    return True


def _extract_names_from_ar_isnad(isnad: str) -> list[str]:
    """
    Parse authenticated Arabic isnad only:
      حدثنا / حدثني / أخبرنا / أخبرني / عن / سمعت / قال / قالت … + FULL NAME
    Collect every narrator in document order until the Prophet ﷺ boundary.
    Never invent names; never take Matn phrases as rawi.
    Transmission connectors are stripped from names via _clean_name_ar.
    """
    if not isnad:
        return []

    display, search = _prepare_isnad_display(isnad)
    # (start_offset, name) — sorted into document order at the end.
    ordered: list[tuple[int, str]] = []
    seen: set[str] = set()

    def add(raw: str, pos: int) -> bool:
        name = _clean_name_ar(raw)
        if not name or _is_prophet_token(name) or _is_matn_noise(name):
            return False
        if not _looks_like_person_name(name):
            return False
        # Strip leftover parallel-chain crumbs.
        name = re.split(r"\s+\.\s+", name)[0].strip(" ،,;:")
        name = _clean_name_ar(name)
        if not name or _is_matn_noise(name) or not _looks_like_person_name(name):
            return False
        # Split apposition "أبو النعمان، عارم بن الفضل" into two display names.
        if "،" in name or "," in name:
            parts = re.split(r"[،,]", name)
            added_any = False
            for part in parts:
                part = _clean_name_ar(part)
                if not part or not _looks_like_person_name(part):
                    continue
                key = _fold_ar(part).replace(" ", "")
                if key in seen:
                    continue
                seen.add(key)
                ordered.append((pos, part))
                added_any = True
                pos += 1  # keep relative order of apposition parts
            return added_any
        key = _fold_ar(name).replace(" ", "")
        if key in seen:
            return False
        seen.add(key)
        ordered.append((pos, name))
        return True

    # 1) قال / قالت <Name> (e.g. قالت أسماء، قال ابن شهاب) — skip matn speech.
    for m in _QALA_NAME.finditer(search):
        candidate = display[m.start("name") : m.end("name")]
        folded = _fold_ar(candidate)
        if _MATN_AFTER_QALA.match(folded):
            continue
        # Only keep short person-like qala-names (ابن / أبو / single ism).
        if len(folded.split()) > 5 or len(folded) > 40:
            continue
        if folded.startswith("قال ") or folded.startswith("قلت "):
            continue
        add(candidate, m.start("name"))

    # 2) Transmission markers: حدثنا / عن / سمعت / …
    matches = list(_TX_FIND.finditer(search))
    for i, m in enumerate(matches):
        verb = m.group("verb")
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(search)
        # Skip "عن" that is part of يحدث عن <matn>
        prev = search[max(0, m.start() - 8) : m.start()]
        if verb == "عن" and re.search(r"يحدث\s*$|تحدث\s*$|نحدث\s*$", prev):
            continue
        # Skip "ان" that opens speech: انه قال / انها قالت
        if verb == "ان":
            ahead = search[start : start + 16]
            if re.match(r"\s*(?:ه\s+قال|ها\s+قالت|ه\s+سمع|ها\s+سمعت)", ahead):
                continue

        chunk = display[start:end].strip(" ،,;:")
        if not chunk:
            continue

        folded_chunk = _fold_ar(chunk)
        # Companion begins matn speech after قال — stop (do not treat as narrator).
        if re.match(r"^(?:انها\s+قالت|انه\s+قال)", folded_chunk):
            break
        if _MATN_AFTER_QALA.match(folded_chunk):
            break
        if re.match(r"^(?:قال\s+رسول|قالت\s+رسول|وهو\s+يحدث|فقال\s+في)", folded_chunk):
            break
        # Bare prophet titles (with salawat) end the chain; bare محمد does not.
        if _is_prophet_token(chunk):
            break
        if _is_matn_noise(chunk):
            break

        # If chunk is "<name> قال <matn…>", keep only the name before قال.
        m_speech = re.search(
            r"\s+قال(?:ت)?\s+(?=تخلف|بينما|بينا|كان|كنت|كنا|ذكر|خطب|جاء|بعث|كتب|يسروا|تسموا|حفظت)",
            folded_chunk,
        )
        if m_speech:
            chunk = display[start : start + m_speech.start()].strip(" ،,;:")
            add(chunk, start)
            break

        add(chunk, start)

    ordered.sort(key=lambda x: x[0])
    return [name for _, name in ordered]


def _cut_isnad_en(text_en: str) -> str:
    plain = text_en or ""
    m = _PROPHET_EN.search(plain)
    if not m:
        return plain[:400]
    return plain[: m.start()].strip(" ,;:")


_EN_NARRATOR_NOISE = re.compile(
    r"^(?:it|this|the above|another|a tradition|a hadith|narrated|reported|one|some|people|"
    r"he|she|they|we|i|and|or|from|that|when|while|after|before|also|same|"
    r"the prophet|allah|messenger|narrator not mentioned|see translation|"
    r"the same|the like)\b",
    re.I,
)

# Authenticated English companion / attributed-narrator patterns (never invent).
_EN_NARRATOR_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"^\s*Narrated\s+(.+?)(?:\s*:|\s*\(|\s*$)", re.I | re.S),
    re.compile(r"^\s*It (?:is|was) narrated on the authority of\s+(.+?)(?:\s+that\b|\s*:)", re.I),
    re.compile(r"^\s*It (?:is|was) reported on the authority of\s+(.+?)(?:\s+that\b|\s*:)", re.I),
    re.compile(
        r"^\s*It has been (?:narrated|reported|related|transmitted) on the authority of\s+(.+?)"
        r"(?:\s+that\b|\s*:|\s+who\b|\s*,|\s*\.)",
        re.I,
    ),
    re.compile(
        r"^\s*(?:This hadith|A hadith like this|The above hadith|The same hadith)"
        r"[^.!?]{0,120}?\bon the authority of\s+(.+?)"
        r"(?:\s+with\b|\s+that\b|\s+from\b|\s+through\b|\s*,|\s*\.|$)",
        re.I,
    ),
    re.compile(
        r"^\s*(?:This hadith|A hadith like this)"
        r"[^.!?]{0,80}?\b(?:narrated|reported|transmitted)\s+by\s+(.+?)"
        r"(?:\s+with\b|\s+through\b|\s+on\b|\s*,|\s*\.|$)",
        re.I,
    ),
    re.compile(r"^\s*It was narrated from\s+(.+?)(?:\s+that\b|\s*,\s*who\b|\s*:)", re.I),
    re.compile(r"^\s*It was narrated that\s+(.+?)(?:\s+said\b|\s*:)", re.I),
    re.compile(r"^\s*(.+?)\s+narrated\s+that\s*:?", re.I),
    re.compile(r"^\s*(.+?)\s+narrated\s*:", re.I),
    re.compile(r"^\s*(.+?)\s+narrated\s+on the authority of\b", re.I),
    re.compile(r"^\s*(.+?)\s+reported\s*:", re.I),
    re.compile(r"^\s*(.+?)\s+reported\s+that\b", re.I),
    re.compile(r"^\s*(.+?)\s+reported\s+on the authority of\b", re.I),
    re.compile(r"^\s*(.+?)\s+reported\s+Allah'?s\s+(?:Messenger|Apostle)\b", re.I),
    re.compile(r"^\s*(.+?)\s*\(\s*Allah be pleased[^)]*\)\s*reported\b", re.I),
    re.compile(r"^\s*(.+?)\s+said\s*:", re.I),
]

_ON_AUTH_EN = re.compile(r"on(?: the)? authority of\s+([^,.\n]+)", re.I)


def _looks_like_en_narrator(name: str) -> bool:
    name = (name or "").strip(" '\"`")
    if not name or len(name) < 2 or len(name) > 90:
        return False
    if _EN_NARRATOR_NOISE.match(name):
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


def _extract_narrated_en(text_en: str | None) -> list[str]:
    """Extract attributed narrator from authenticated English text only (never invent)."""
    text = (text_en or "").strip()
    if not text:
        return []
    for pat in _EN_NARRATOR_PATTERNS:
        m = pat.match(text)
        if not m:
            continue
        name = _clean_name_en(m.group(1))
        name = re.sub(r"\s*\(.*$", "", name).strip()
        if _looks_like_en_narrator(name):
            return [name]
    matches = list(_ON_AUTH_EN.finditer(text))
    if matches:
        head = [m for m in matches if m.start() < 520] or matches
        for m in reversed(head):
            name = _clean_name_en(m.group(1))
            name = re.sub(r"\s*\(.*$", "", name).strip()
            if _looks_like_en_narrator(name):
                return [name]
    # Legacy Bukhari-style head cut fallback
    head = _cut_isnad_en(text) if _PROPHET_EN.search(text) else text.split(".", 1)[0]
    m = re.match(
        r"^\s*Narrated\s+(.+?)(?:\s*[:.\n]|\s+that\b|\s+said\b|\s+reported\b)",
        head,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not m:
        return []
    name = _clean_name_en(m.group(1))
    return [name] if name and _looks_like_en_narrator(name) else []


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
) -> dict[str, list[str]]:
    """Authenticated rawi lists keyed by language code."""
    ar = extract_ravi_chain(text_ar, primary, text_en, text_ur)
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
        "source_url": "",
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

