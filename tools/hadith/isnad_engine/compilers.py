"""Authenticated collection compilers (not part of the rawi chain)."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CompilerInfo:
    book_slug: str
    name_ar: str
    name_en: str


# Canonical compilers of the supported collections.
# Musnad Ahmad is reserved for future import — same parser, no logic fork.
COMPILERS: dict[str, CompilerInfo] = {
    "bukhari": CompilerInfo("bukhari", "محمد بن إسماعيل البخاري", "Muhammad ibn Ismail al-Bukhari"),
    "muslim": CompilerInfo("muslim", "مسلم بن الحجاج", "Muslim ibn al-Hajjaj"),
    "abudawud": CompilerInfo("abudawud", "أبو داود سليمان بن الأشعث", "Abu Dawud Sulayman ibn al-Ash'ath"),
    "tirmidhi": CompilerInfo("tirmidhi", "محمد بن عيسى الترمذي", "Muhammad ibn Isa al-Tirmidhi"),
    "nasai": CompilerInfo("nasai", "أحمد بن شعيب النسائي", "Ahmad ibn Shu'ayb al-Nasa'i"),
    "ibnmajah": CompilerInfo("ibnmajah", "محمد بن يزيد ابن ماجه", "Muhammad ibn Yazid Ibn Majah"),
    "malik": CompilerInfo("malik", "مالك بن أنس", "Malik ibn Anas"),
    "ahmad": CompilerInfo("ahmad", "أحمد بن حنبل", "Ahmad ibn Hanbal"),
}


def compiler_for(book_slug: str) -> CompilerInfo:
    slug = (book_slug or "").strip().lower()
    if slug in COMPILERS:
        return COMPILERS[slug]
    return CompilerInfo(slug or "unknown", "", "")
