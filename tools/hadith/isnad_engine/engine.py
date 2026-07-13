"""Orchestrate Arabic Isnad Engine parsing for any supported collection."""

from __future__ import annotations

from .compilers import compiler_for
from .confidence import REVIEW_THRESHOLD, score_chain
from .models import ExtractedHadithIsnad, SanadChain
from .parse import parse_links
from .registry import NarratorRegistry
from .split import split_matn, split_parallel_isnads


class IsnadEngine:
    def __init__(self, registry: NarratorRegistry | None = None) -> None:
        self.registry = registry or NarratorRegistry()

    def parse(
        self,
        *,
        text_ar: str | None,
        book_slug: str,
        hadith_number: int = 0,
    ) -> ExtractedHadithIsnad:
        compiler = compiler_for(book_slug)
        compiler_rec = None
        if compiler.name_ar:
            compiler_rec = self.registry.get_or_create(compiler.name_ar)

        isnad_ar, matn_ar = split_matn(text_ar or "")
        had_parallel = bool(
            isnad_ar
            and (
                " ح " in f" {isnad_ar} "
                or "ح وحدث" in isnad_ar.replace(" ", "")
                or "ححدث" in isnad_ar.replace(" ", "")
            )
            or (text_ar and (" ح " in f" {text_ar} " or "ح وحدثنا" in (text_ar or "")))
        )

        segments = split_parallel_isnads(isnad_ar) if isnad_ar else []
        # If parallel marker in full text but cut dropped it, split original isnad cut only.
        if not segments and isnad_ar:
            segments = [isnad_ar]

        chains: list[SanadChain] = []
        for idx, seg in enumerate(segments):
            links, unresolved, leak = parse_links(seg, self.registry)
            chain = SanadChain(
                chain_index=idx,
                links=links,
                isnad_ar=seg,
                matn_ar=matn_ar if idx == 0 else "",
            )
            conf, reasons = score_chain(
                chain,
                had_parallel_marker=had_parallel,
                cut_ok=bool(isnad_ar),
                unresolved_relatives=unresolved,
                matn_leak_suspect=leak,
                empty=not links,
            )
            if had_parallel and len(segments) < 2:
                conf = max(0.0, conf - 10)
                reasons.append("parallel_marker_unsplit")
            chain.confidence = conf
            chain.review_reasons = reasons
            chain.needs_review = conf < REVIEW_THRESHOLD
            chains.append(chain)

        if not chains:
            empty = SanadChain(chain_index=0, isnad_ar=isnad_ar, matn_ar=matn_ar, confidence=0.0)
            empty.needs_review = True
            empty.review_reasons = ["empty_sanad"]
            chains = [empty]

        overall = min(c.confidence for c in chains)
        return ExtractedHadithIsnad(
            book_slug=book_slug,
            hadith_number=hadith_number,
            compiler_id=compiler_rec.id if compiler_rec else None,
            compiler_name_ar=compiler.name_ar,
            compiler_name_en=compiler.name_en,
            chains=chains,
            overall_confidence=overall,
            needs_review=overall < REVIEW_THRESHOLD or any(c.needs_review for c in chains),
        )


def parse_hadith_isnad(
    text_ar: str | None,
    *,
    book_slug: str,
    hadith_number: int = 0,
    registry: NarratorRegistry | None = None,
) -> ExtractedHadithIsnad:
    return IsnadEngine(registry).parse(
        text_ar=text_ar, book_slug=book_slug, hadith_number=hadith_number
    )
