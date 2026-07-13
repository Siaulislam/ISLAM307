"""Split parallel isnads (ح) and separate matn from sanad."""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Reuse battle-tested matn cut from hadith_meta (sanad-only rules).
_TOOLS = Path(__file__).resolve().parents[1]
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from hadith_meta import _cut_isnad_ar, _fold_ar, _strip_diac  # noqa: E402

# Parallel-chain markers: ح / ح وحدثنا / ثم حدثنا / وحدثنا (not واخبرني continuation).
_PARALLEL_SPLIT = re.compile(
    r"(?:^|[\s،,;])(?:ح)\s*و?\s*(?=حدثنا|حدثني|اخبرنا|اخبرني)"
    r"|(?:^|[\s،,;])ثم\s+(?=حدثنا|حدثني|اخبرنا|اخبرني)"
    r"|(?:^|[\s،,;])و(?=حدثنا|حدثني)",
    re.UNICODE,
)

_SHARED_AFTER_NAHWUHU = re.compile(
    r"نحوه\s*(?P<shared>قال\s+أخبرني.+)$"
    r"|نحوه\s*(?P<shared2>قال\s+اخبرني.+)$",
    re.UNICODE,
)


def strip_diac(text: str) -> str:
    return _strip_diac(text)


def fold_ar(text: str) -> str:
    return _fold_ar(text)


def cut_isnad_ar(text_ar: str) -> str:
    return _cut_isnad_ar(text_ar)


def split_matn(text_ar: str) -> tuple[str, str]:
    """Return (isnad_ar, matn_ar) using sanad-only cut."""
    text = (text_ar or "").strip()
    if not text:
        return "", ""
    isnad = cut_isnad_ar(text)
    if not isnad:
        return "", text
    # Approximate matn start in original (diacritics may shift length slightly).
    plain = fold_ar(strip_diac(text))
    cut_plain = fold_ar(strip_diac(isnad))
    if not plain:
        return isnad, ""
    ratio = len(cut_plain) / max(len(plain), 1)
    idx = max(1, min(len(text), int(len(text) * ratio)))
    # Snap forward to next punctuation when possible
    for j in range(idx, min(len(text), idx + 40)):
        if text[j] in ":.۔\"«":
            idx = j + 1
            break
    matn = text[idx:].strip(" ،,;:")
    return isnad.strip(), matn


def split_parallel_isnads(isnad_ar: str) -> list[str]:
    """
    Split on ح / ح وحدثنا / وح حدثنا into separate sanads.
    Shared tail after نحوه (common lower isnad) is appended to every branch.
    """
    text = strip_diac(isnad_ar or "").strip()
    if not text:
        return []

    folded = fold_ar(text)
    # Detect shared suffix after نحوه
    shared = ""
    m = re.search(r"نحوه\s+(قال\s+(?:أخبرني|اخبرني).+)$", text)
    if not m:
        m = re.search(r"نحوه\s+(قال\s+(?:أخبرني|اخبرني).+)$", folded)
        if m:
            # map roughly — use folded match on display text length
            shared = m.group(1)
    else:
        shared = m.group(1)
        # Remove shared from working text so prefixes stay clean
        text = text[: m.start()].rstrip(" ،,")

    parts: list[str] = []
    last = 0
    for m in _PARALLEL_SPLIT.finditer(fold_ar(text)):
        # m starts at whitespace/ح — find corresponding in display via fold alignment (1:1 after strip)
        start = m.start()
        # Include the ح boundary as split point: take preceding segment
        chunk = text[last:start].strip(" ،,;:")
        if chunk:
            parts.append(chunk)
        # Skip leading ح و?
        # Advance last to after the ح marker inside display text
        # fold positions == display positions when both stripped of diacritics
        # Consume 'ح' and optional و
        j = start
        disp = fold_ar(text)
        while j < len(disp) and disp[j] in " \t،,;":
            j += 1
        if j < len(disp) and disp[j] == "ح":
            j += 1
        while j < len(disp) and disp[j] in " \tو":
            if disp[j] == "و":
                j += 1
                break
            j += 1
        last = j
    tail = text[last:].strip(" ،,;:")
    if tail:
        parts.append(tail)
    if not parts:
        parts = [text]

    if shared:
        parts = [f"{p} {shared}".strip() if "أخبرني" not in p and "اخبرني" not in fold_ar(p) else p for p in parts]

    # Drop empty / commentary-only
    cleaned = []
    for p in parts:
        p2 = re.sub(r"،?\s*نحوه\s*", " ", p).strip(" ،,;:")
        if p2 and len(p2) > 3:
            cleaned.append(p2)
    return cleaned or [text]
