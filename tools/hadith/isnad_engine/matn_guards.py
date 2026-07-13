"""Matn openers, story characters, and non-narrator grammar."""

from __future__ import annotations

import re

# Folded forms (search text is hamza-folded). Optional leading ف/و for فقام etc.
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
    "سيل",
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
    "صلي",
    "نهي",
    "امر",
)

# Story / Matn characters — never narrators (folded / display variants).
STORY_CHARACTERS = {
    "هرقل",
    "كسري",
    "كسرى",
    "النجاشي",
    "المقوقس",
    "ابو جهل",
    "ابا جهل",
    "ابو لهب",
    "ابا لهب",
    "اميه بن خلف",
    "امية بن خلف",
    "عتبه بن ربيعه",
    "عتبة بن ربيعة",
    "شيطان",
    "ابليس",
    "امراة",
    "امرأة",
    "رجل",
    "قوم",
    "ناس",
    "الحارث بن هشام",
}

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
    "ان",  # إن / أن opening matn clauses (not أن NAME أخبره — handled elsewhere)
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
    "نحن",
    "الله",  # bare الله from إن الله is not a narrator
}

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

# Verb alt with optional ف/و prefix (فقام، وخرج).
_MATN_VERB_ALT = "|".join(MATN_OPEN_VERBS)
_MATN_VERB_PREF = rf"(?:[فو])?(?:{_MATN_VERB_ALT})"

# Shared pattern string for cut/peel (folded text).
MATN_VERB_CUT_ALT = _MATN_VERB_PREF

PROPHET_MATN_VERB = re.compile(
    rf"^(?:{_MATN_VERB_PREF})"
    rf"(?:\s+فينا)?"
    rf"\s*(?:رسول\s*الله|النبي\b|نبي\s*الله)",
    re.UNICODE,
)

PROPHET_DISPLAY = "رسول الله ﷺ"


def looks_like_matn_verb_name(name: str) -> bool:
    from .normalize import fold_hamza, normalize_display_ar

    n = fold_hamza(normalize_display_ar(name))
    if not n:
        return True
    if n in GRAMMAR_TOKENS or n in TX_GRAMMAR:
        return True
    if is_story_character(n):
        return True
    if re.match(rf"^(?:{_MATN_VERB_PREF})(?:\s+فينا)?(?:\s|$)", n):
        parts = n.split()
        clear = {
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
            "سيل",
            "فينا",
            "صلي",
            "نهي",
            "امر",
            "اتي",
            "جاء",
            "فقام",
            "فخرج",
            "فدخل",
        }
        if len(parts) == 1 and (parts[0] in clear or parts[0].lstrip("فو") in clear):
            return True
        if len(parts) >= 2:
            return True
    return False


def is_story_character(name: str) -> bool:
    from .normalize import fold_hamza, normalize_display_ar, normalize_key

    n = fold_hamza(normalize_display_ar(name))
    key = normalize_key(name)
    if n in STORY_CHARACTERS or key in {normalize_key(s) for s in STORY_CHARACTERS}:
        return True
    # Prefix / contains known enemies & kings as whole token
    for s in (
        "هرقل",
        "كسري",
        "النجاشي",
        "المقوقس",
        "ابو جهل",
        "ابو لهب",
        "ابليس",
        "شيطان",
    ):
        if n == s or n.startswith(s + " ") or key == s.replace(" ", ""):
            return True
    if n in {"رجل", "امراة", "قوم", "ناس"}:
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
        if cut and cut in plain:
            rest = plain[plain.find(cut) + len(cut) :]
        else:
            rest = plain[len(cut) :] if cut else plain
    else:
        rest = plain
    head = rest.strip(" ،,;:")[:55]
    if not head:
        m = re.search(
            rf"قال(?:ت)?\s*:?\s*((?:{_MATN_VERB_PREF}|سمعت).{{0,50}})",
            plain,
        )
        head = (m.group(1) if m else "")[:55]
    # Strip a leading ف before verb for فقام
    head_chk = re.sub(r"^ف(?=قام|خرج|دخل|جاء|اتي)", "", head)
    if PROPHET_MATN_VERB.search(head) or PROPHET_MATN_VERB.search(head_chk):
        return True
    if re.search(
        r"(?:^|قال(?:ت)?\s*:?\s*)(?:سمعت|سمع|قال)\s+(?:رسول\s*الله|النبي)|"
        rf"(?:^|قال(?:ت)?\s*:?\s*)(?:{_MATN_VERB_PREF})"
        r"\s+(?:فينا\s+)?(?:رسول\s*الله|النبي)|"
        r"^ان\s+رسول\s*الله|"
        r"^ان\s+النبي\s+قال",
        head,
    ):
        return True
    return False


def qala_opens_matn(ahead: str) -> bool:
    """True if text after قال/قالت starts the Matn."""
    a = (ahead or "").lstrip()
    if not a:
        return False
    if re.match(
        rf"^(?:{_MATN_VERB_PREF})\b|رسول\s*الله|النبي\b|"
        r"ان\s+الحارث|ان\s+ابا\s+سفيان|ان\s+هرقل|"
        r"بلغ\s+|وهو\s+|نحن\b|"
        r"اذا\b|اذ\b|ان\s+(?!ه\s+سمع)(?!ها\s+سمعت)|"
        r"سمعت\s+رسول|اخبرني\s+(?:ابو|ابا)\s+سفيان",
        a,
    ):
        return True
    return False
