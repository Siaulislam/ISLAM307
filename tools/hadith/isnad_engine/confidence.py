"""Parser confidence scoring (0–100)."""

from __future__ import annotations

from .models import SanadChain

REVIEW_THRESHOLD = 95.0


def score_chain(
    chain: SanadChain,
    *,
    had_parallel_marker: bool = False,
    cut_ok: bool = True,
    unresolved_relatives: int = 0,
    matn_leak_suspect: bool = False,
    empty: bool = False,
) -> tuple[float, list[str]]:
    """Return (confidence 0–100, review_reasons)."""
    reasons: list[str] = []
    score = 100.0

    if empty or not chain.links:
        return 0.0, ["empty_sanad"]

    if not cut_ok:
        score -= 25
        reasons.append("weak_matn_cut")

    if matn_leak_suspect:
        score -= 40
        reasons.append("matn_leak_suspect")

    if unresolved_relatives:
        score -= 8 * unresolved_relatives
        reasons.append(f"unresolved_relative:{unresolved_relatives}")

    # Very short chains are often incomplete excerpts / bi-isnadihi continuations.
    if len(chain.links) == 1:
        score -= 15
        reasons.append("single_link_chain")

    if len(chain.links) > 14:
        score -= 10
        reasons.append("unusually_long_chain")

    # Parallel marker present but only one chain parsed → incomplete split.
    if had_parallel_marker and chain.chain_index == 0:
        # Informational only when multiple chains exist; checked at hadith level.
        pass

    # Unresolved relative leaves narrator_id None
    missing_ids = sum(1 for lnk in chain.links if lnk.ref.narrator_id is None)
    if missing_ids:
        score -= 12 * missing_ids
        reasons.append(f"missing_narrator_id:{missing_ids}")

    score = max(0.0, min(100.0, score))
    if score < REVIEW_THRESHOLD and "below_threshold" not in reasons:
        reasons.append("below_threshold")
    return score, reasons
