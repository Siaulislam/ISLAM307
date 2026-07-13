"""Matn openers and non-narrator grammar — never extract as rawi names."""

from __future__ import annotations

import re

# Clear Matn-opening verbs (safe to reject as names). Exclude tokens that
# commonly appear inside authentic personal names (نسي، حفظ، ذكر، سمع، …).
MATN_OPEN_VERBS = (
    "قام",
    "جلس",
    "خرج",
    "دخل",
    "اتي",
    "جاء",
    "ذهب",
    "راي",
    "نظر",
    "خطب",
    "خطبنا",
    "قرا",
    "كتب",
    "تكلم",
    "دعا",
    "سال",
    "سالت",
    "سيل",  # folded سئل
    "سئل",
    "اجاب",
    "اخذ",
    "اعطي",
    "رفع",
    "خفض",
    "وقف",
    "مشي",
    "رجع",
    "بعث",
    "ارسل",
    "دخلنا",
    "خرجنا",
    "نزل",
    "بينا",
    "بينما",
    "كان",
    "كنت",
    "كنا",
    "فكان",
    "وكان",
)

# Particles / grammar that are never person names.
GRAMMAR_TOKENS = {
    "قال",
    "قالت",
    "قلت",
    "قلنا",
    "فقال",
    "فقلت",
    "يقول",
    "ثم",
    "ف",
    "و",
    "او",
    "بل",
    "لكن",
    "اذا",
    "اذ",
    "حتي",
    "بعد",
    "قبل",
    "حين",
    "حيث",
    "هناك",
    "هنا",
    "فينا",
    "منه",
    "عنه",
    "اليه",
    "عليها",
    "عليهم",
}

# Transmission grammar (never narrators).
TX_GRAMMAR = {
    "حدثنا",
    "حدثني",
    "اخبرنا",
    "اخبرني",
    "انبانا",
    "انباني",
    "سمعت",
    "عن",
    "انه",
    "انها",
    "حدث",
    "حدثه",
    "روي",
    "يرويه",
    "ذكر",
    "بلغ",
    "بلغنا",
    "بلغني",
}

_MATN_VERB_ALT = "|".join(MATN_OPEN_VERBS)

# قال / قالت then matn verb or Prophet — sanad ends at قال.
QALA_MATN_OPEN = re.compile(
    rf"(?P<qala>قال(?:ت)?)\s*:?\s*"
    rf"(?="
    rf"(?:{_MATN_VERB_ALT})\b|"
    rf"رسول\s*الله|النبي\b|نبي\s*الله|"
    rf"ان\s+الحارث|ان\s+ابا\s+سفيان|ان\s+هرقل|"
    rf"بلغ\s+|وهو\s+"
    rf")",
    re.UNICODE,
)

# Verb (+ optional فينا) + Prophet at Matn start — not mid-story.
PROPHET_MATN_VERB = re.compile(
    rf"^(?:{_MATN_VERB_ALT})"
    rf"(?:\s+فينا)?"
    rf"\s*(?:رسول\s*الله|النبي\b|نبي\s*الله)",
    re.UNICODE,
)

PROPHET_DISPLAY = "رسول الله ﷺ"


def looks_like_matn_verb_name(name: str) -> bool:
    """True if a candidate 'name' is really a matn verb / grammar blob."""
    from .normalize import fold_hamza, normalize_display_ar

    n = fold_hamza(normalize_display_ar(name))
    if not n:
        return True
    if n in GRAMMAR_TOKENS or n in TX_GRAMMAR:
        return True
    # "قام فينا" / "خرج رسول…" style blobs
    if re.match(rf"^(?:{_MATN_VERB_ALT})(?:\s+فينا)?(?:\s|$)", n):
        # Allow single-token only for unambiguous matn openers (not name endings).
        parts = n.split()
        if len(parts) == 1 and parts[0] in {
            "قام",
            "جلس",
            "خرج",
            "دخل",
            "خطب",
            "بعث",
            "ارسل",
            "بينما",
            "بينا",
            "كان",
            "سئل",
            "فينا",
        }:
            return True
        if len(parts) >= 2:
            return True
    return False


def should_append_prophet(text_ar: str, isnad_ar: str = "") -> bool:
    """Matn *opening* is Prophet speech/action (not a later story mention)."""
    from hadith_meta import _fold_ar, _strip_diac

    plain = _fold_ar(_strip_diac(text_ar or ""))
    if not plain:
        return False
    if isnad_ar:
        cut = _fold_ar(_strip_diac(isnad_ar))
        # Find cut end in plain
        if cut and cut in plain:
            rest = plain[plain.find(cut) + len(cut) :]
        else:
            # ratio fallback
            rest = plain[len(cut) :] if cut else plain
    else:
        rest = plain
    head = rest.strip(" ،,;:")[:50]
    if not head:
        m = re.search(
            r"قال(?:ت)?\s*:?\s*((?:قام|جلس|خرج|دخل|خطب|بعث|ارسل|بينما|بينا|كان|سيل|سئل|سال|سمعت).{0,50})",
            plain,
        )
        head = (m.group(1) if m else "")[:120]
    if PROPHET_MATN_VERB.search(head):
        return True
    if re.search(
        r"(?:^|قال(?:ت)?\s*:?\s*)(?:سمعت|سمع|قال)\s+(?:رسول\s*الله|النبي)|"
        r"(?:^|قال(?:ت)?\s*:?\s*)(?:قام|جلس|خرج|دخل|خطب|بعث|ارسل|بينما|بينا|كان|سيل)"
        r"\s+(?:فينا\s+)?(?:رسول\s*الله|النبي)|"
        r"^ان\s+رسول\s*الله|"
        r"^ان\s+النبي\s+قال",
        head,
    ):
        return True
    return False
