"""Arabic name normalization for isnad matching (never invents identities)."""

from __future__ import annotations

import re
import unicodedata

_DIAC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")
_TATWEEL = "\u0640"
_HONOR = re.compile(
    r"\s*(?:"
    r"(?:رضي|رضى)\s*الله\s*(?:عنهما|عنها|عنهم|عنه)|"
    r"رحمه(?:ما|ا)?\s*الله|"
    r"رحمها\s*الله|"
    r"عليه(?:ما|ا)?\s*السلام|"
    r"صلى\s*الله\s*عليه(?:\s*وآله)?\s*وسلم"
    r")\s*",
    re.UNICODE,
)
_SPACE = re.compile(r"\s+")

# Relative tokens — never stored as narrator display names.
RELATIVE_FORMS: dict[str, str] = {
    "ابيه": "father",
    "اباه": "father",
    "ابوه": "father",
    "والده": "father",
    "امه": "mother",
    "امها": "mother",
    "والدته": "mother",
    "جده": "grandfather",
    "جداها": "grandfather",
    "اخيه": "brother",
    "اخاه": "brother",
    "عمه": "uncle_paternal",
    "خاله": "uncle_maternal",
}


def strip_diacritics(text: str) -> str:
    return _DIAC.sub("", text or "")


def fold_hamza(text: str) -> str:
    t = strip_diacritics(text)
    return (
        t.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ؤ", "و")
        .replace("ئ", "ي")
        .replace("ى", "ي")
        .replace("ة", "ه")
    )


def normalize_ws(text: str) -> str:
    return _SPACE.sub(" ", text or "").strip()


def normalize_display_ar(raw: str) -> str:
    """Human-facing Arabic: strip honorifics/tatweel/diacritics; keep spelling shape."""
    t = unicodedata.normalize("NFC", raw or "")
    t = t.replace(_TATWEEL, "")
    t = strip_diacritics(t)
    t = _HONOR.sub(" ", t)
    t = normalize_ws(t).strip(" ،,;:.-")
    return t


def normalize_key(raw: str) -> str:
    """
    Matching key for duplicate detection.
    عبدالله / عبد الله / عبد اللّٰه → عبدالله
    ابن/بن → بن ; أبو/ابو → ابو
    """
    t = normalize_display_ar(raw)
    t = t.replace("ﷺ", "")
    t = fold_hamza(t)
    t = t.replace("ابن", "بن")
    # Collapse عبد الله → عبدالله (and similar spaced compounds used as one person)
    t = re.sub(r"عبد\s+ال", "عبدال", t)
    t = re.sub(r"ابو\s+", "ابو", t)
    t = re.sub(r"ام\s+", "ام", t)
    t = t.replace(" ", "")
    t = t.replace("ـ", "")
    return t


def match_key(raw: str) -> str:
    """Alias used by registry lookups."""
    return normalize_key(raw)


def relative_type(token: str) -> str | None:
    key = normalize_key(token)
    # normalize_key collapses spaces; relatives are short
    folded = fold_hamza(normalize_display_ar(token)).replace(" ", "")
    return RELATIVE_FORMS.get(folded) or RELATIVE_FORMS.get(key)


def is_relative_token(token: str) -> bool:
    return relative_type(token) is not None


def extract_ibn_parent(name_ar: str) -> str | None:
    """
    If name is like هشام بن عروة / محمد ابن إبراهيم, return the parent segment
    already present in the authenticated name (عروة / إبراهيم).
    Does not invent a full expanded identity.
    """
    display = normalize_display_ar(name_ar)
    folded = fold_hamza(display)
    m = re.search(
        r"(?:^|\s)(?:بن|ابن)\s+([^،,;]+?)(?:\s+(?:بن|ابن)\s+|$)",
        folded,
    )
    if not m:
        return None
    parent = normalize_ws(m.group(1))
    # Prefer original orthography from display when possible
    m2 = re.search(r"(?:^|\s)(?:بن|ابن)\s+([^،,;]+?)(?:\s+(?:بن|ابن)\s+|$)", display)
    if m2:
        return normalize_ws(m2.group(1))
    return parent or None
