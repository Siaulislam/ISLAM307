"""Data models for the Arabic Isnad Engine."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass
class NarratorRef:
    """A narrator identity (by permanent ID) or an unresolved relative."""

    narrator_id: int | None
    display_name_ar: str
    normalized_key: str
    relation_type: str | None = None  # father|mother|grandfather|brother|uncle_paternal|uncle_maternal
    relative_to_position: int | None = None
    resolved_from_relative: bool = False
    surface_form: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SanadLink:
    """One hop in a sanad (position 0 = first transmitter after compiler)."""

    position: int
    ref: NarratorRef
    transmission_verb: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "position": self.position,
            "transmission_verb": self.transmission_verb,
            **self.ref.to_dict(),
        }


@dataclass
class SanadChain:
    """One complete isnad (parallel chains stay separate)."""

    chain_index: int
    links: list[SanadLink] = field(default_factory=list)
    isnad_ar: str = ""
    matn_ar: str = ""
    confidence: float = 0.0
    needs_review: bool = True
    review_reasons: list[str] = field(default_factory=list)

    @property
    def narrator_ids(self) -> list[int]:
        return [lnk.ref.narrator_id for lnk in self.links if lnk.ref.narrator_id is not None]

    @property
    def display_names(self) -> list[str]:
        return [lnk.ref.display_name_ar for lnk in self.links if lnk.ref.display_name_ar]

    def to_dict(self) -> dict[str, Any]:
        return {
            "chain_index": self.chain_index,
            "isnad_ar": self.isnad_ar,
            "matn_ar": self.matn_ar,
            "confidence": self.confidence,
            "needs_review": self.needs_review,
            "review_reasons": list(self.review_reasons),
            "narrator_ids": self.narrator_ids,
            "links": [lnk.to_dict() for lnk in self.links],
        }


@dataclass
class ExtractedHadithIsnad:
    """Full parse result for one hadith row."""

    book_slug: str
    hadith_number: int
    compiler_id: int | None
    compiler_name_ar: str
    compiler_name_en: str
    chains: list[SanadChain] = field(default_factory=list)
    overall_confidence: float = 0.0
    needs_review: bool = True

    @property
    def primary_chain(self) -> SanadChain | None:
        return self.chains[0] if self.chains else None

    @property
    def primary_names(self) -> list[str]:
        return self.primary_chain.display_names if self.primary_chain else []

    @property
    def primary_ids(self) -> list[int]:
        return self.primary_chain.narrator_ids if self.primary_chain else []

    def to_dict(self) -> dict[str, Any]:
        return {
            "book_slug": self.book_slug,
            "hadith_number": self.hadith_number,
            "compiler_id": self.compiler_id,
            "compiler_name_ar": self.compiler_name_ar,
            "compiler_name_en": self.compiler_name_en,
            "overall_confidence": self.overall_confidence,
            "needs_review": self.needs_review,
            "chains": [c.to_dict() for c in self.chains],
            "primary_narrator_ids": self.primary_ids,
            "primary_names": self.primary_names,
        }
