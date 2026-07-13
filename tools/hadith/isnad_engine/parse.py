"""Extract sanad links from a single (already-split) Arabic isnad segment."""

from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[1]
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from hadith_meta import (  # noqa: E402
    _AN_AKHBARAHU,
    _AN_QALA,
    _QALA_NAME,
    _TX_FIND,
    _clean_name_ar,
    _is_matn_noise,
    _is_prophet_token,
    _prepare_isnad_display,
)

from .normalize import (
    extract_ibn_parent,
    is_relative_token,
    normalize_display_ar,
    relative_type,
)
from .matn_guards import looks_like_matn_verb_name
from .registry import NarratorRegistry
from .models import NarratorRef, SanadLink


_MATN_LEAK = re.compile(
    r"هرقل|سالتك|يزيدون|الحارث بن هشام|انما الاعمال|فزعمت|القريش",
    re.UNICODE,
)


def _surface_tokens_from_isnad(isnad: str) -> list[tuple[int, str, str | None]]:
    """
    Ordered (pos, surface, verb) from authenticated isnad text.
    Relative tokens are returned as-is (not cleaned into fake names).
    """
    if not isnad:
        return []
    display, search = _prepare_isnad_display(isnad)
    found: list[tuple[int, str, str | None]] = []
    seen_pos: set[int] = set()

    def push(pos: int, surface: str, verb: str | None) -> None:
        surface = normalize_display_ar(surface) if not is_relative_token(surface) else normalize_display_ar(surface)
        if not surface:
            return
        # Dedup near-identical positions
        if any(abs(pos - p) < 2 for p in seen_pos):
            return
        seen_pos.add(pos)
        found.append((pos, surface, verb))

    for m in _QALA_NAME.finditer(search):
        push(m.start("name"), display[m.start("name") : m.end("name")], "قال")

    for m in _AN_AKHBARAHU.finditer(search):
        push(m.start("name"), display[m.start("name") : m.end("name")], "ان")

    for m in _AN_QALA.finditer(search):
        push(m.start("name"), display[m.start("name") : m.end("name")], "ان")

    for m in re.finditer(
        r"(?:^|[\s،,;:]+)ان\s+(?P<name>[^،,;:\n\"«»‏]{2,70}?)\s*$",
        search,
    ):
        push(m.start("name"), display[m.start("name") : m.end("name")], "ان")

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
        # Peel nested أن
        folded = chunk
        from hadith_meta import _fold_ar

        folded_chunk = _fold_ar(chunk)
        nested = re.search(r"\sان\s+", folded_chunk)
        if nested:
            chunk = chunk[: nested.start()].strip(" ،,;:")
        chunk = re.sub(r"\s*[،,]?\s*\.\s*$", "", chunk).strip(" ،,;:")
        chunk = re.sub(r"\s*[،,]?\s*(?:يقول|يحدث)\s*:?\s*$", "", chunk).strip(" ،,;:")
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
        if _is_prophet_token(chunk) or (_is_matn_noise(chunk) and not is_relative_token(chunk)):
            parts = re.split(r"\s*،\s*و", chunk)
            if len(parts) > 1:
                offset = start
                for p in parts:
                    p = p.strip()
                    if p and not _is_prophet_token(p) and not _is_matn_noise(p):
                        push(offset, p, verb)
                        offset += len(p) + 1
            continue
        push(start, chunk, verb)

    found.sort(key=lambda t: t[0])
    # Prefer cleaned names for non-relatives
    out: list[tuple[int, str, str | None]] = []
    for pos, surface, verb in found:
        if is_relative_token(surface):
            out.append((pos, surface, verb))
            continue
        cleaned = _clean_name_ar(surface)
        if not cleaned or _is_prophet_token(cleaned) or _is_matn_noise(cleaned):
            continue
        out.append((pos, cleaned, verb))
    return out


def parse_links(
    isnad_ar: str,
    registry: NarratorRegistry,
) -> tuple[list[SanadLink], int, bool]:
    """
    Build SanadLink list with NarratorIDs.
    Returns (links, unresolved_relative_count, matn_leak_suspect).
    """
    tokens = _surface_tokens_from_isnad(isnad_ar)
    links: list[SanadLink] = []
    unresolved = 0
    leak = bool(_MATN_LEAK.search(isnad_ar or ""))

    for surface, verb in ((t[1], t[2]) for t in tokens):
        if looks_like_matn_verb_name(surface):
            continue
        rel = relative_type(surface)
        if rel:
            prev = links[-1] if links else None
            resolved_name = None
            if prev and prev.ref.display_name_ar:
                if rel == "father":
                    resolved_name = extract_ibn_parent(prev.ref.display_name_ar)
            if resolved_name:
                rec = registry.get_or_create(resolved_name)
                ref = NarratorRef(
                    narrator_id=rec.id,
                    display_name_ar=rec.display_name_ar,
                    normalized_key=rec.normalized_key,
                    relation_type=rel,
                    relative_to_position=prev.position if prev else None,
                    resolved_from_relative=True,
                    surface_form=surface,
                )
            else:
                unresolved += 1
                ref = NarratorRef(
                    narrator_id=None,
                    display_name_ar="",  # never store أبيه as a name
                    normalized_key="",
                    relation_type=rel,
                    relative_to_position=prev.position if prev else None,
                    resolved_from_relative=False,
                    surface_form=surface,
                )
            links.append(SanadLink(position=len(links), ref=ref, transmission_verb=verb))
            continue

        if _MATN_LEAK.search(surface):
            leak = True
            continue

        rec = registry.get_or_create(surface)
        ref = NarratorRef(
            narrator_id=rec.id,
            display_name_ar=rec.display_name_ar,
            normalized_key=rec.normalized_key,
            surface_form=surface,
        )
        links.append(SanadLink(position=len(links), ref=ref, transmission_verb=verb))

    return links, unresolved, leak
