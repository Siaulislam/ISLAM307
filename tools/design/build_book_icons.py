#!/usr/bin/env python3
"""Generate ISLAM 307 premium book icons — original Material 3 SVG pack."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "app" / "assets" / "branding" / "books"
MANIFEST = OUT / "books_manifest.json"

BOOKS = [
    ("quran", "Al-Quran Al-Kareem", "القرآن الكريم", 28),
    ("bukhari", "Sahih al-Bukhari", "صحيح البخاري", 26),
    ("muslim", "Sahih Muslim", "صحيح مسلم", 30),
    ("abudawud", "Sunan Abu Dawood", "سنن أبي داود", 22),
    ("tirmidhi", "Jami' at-Tirmidhi", "جامع الترمذي", 24),
    ("nasai", "Sunan an-Nasa'i", "سنن النسائي", 24),
    ("ibnmajah", "Sunan Ibn Majah", "سنن ابن ماجه", 22),
    ("malik", "Muwatta Imam Malik", "موطأ الإمام مالك", 20),
    ("ahmad", "Musnad Ahmad", "مسند أحمد", 28),
    ("riyad-us-saliheen", "Riyad us-Saliheen", "رياض الصالحين", 24),
    ("bulugh-al-maram", "Bulugh al-Maram", "بلوغ المرام", 26),
    ("ibn-kathir", "Tafsir Ibn Kathir", "تفسير ابن كثير", 22),
    ("jalalayn", "Tafsir al-Jalalayn", "تفسير الجلالين", 22),
    ("maarif", "Ma'ariful Quran", "معارف القرآن", 24),
    ("hisn-al-muslim", "Hisn al-Muslim", "حصن المسلم", 28),
]


def svg_for(slug: str, name_en: str, title_ar: str, font_size: int) -> str:
    # Split long titles into two lines at logical break
    parts = title_ar.split(" ")
    if len(title_ar) > 14 and len(parts) >= 2:
        mid = len(parts) // 2
        line1 = " ".join(parts[:mid])
        line2 = " ".join(parts[mid:])
        title_block = f"""
  <text x="256" y="248" text-anchor="middle" fill="url(#goldEmboss)" font-family="'Segoe UI', 'Noto Naskh Arabic', 'Traditional Arabic', serif" font-size="{font_size}" font-weight="700" direction="rtl">{line1}</text>
  <text x="256" y="{248 + font_size + 8}" text-anchor="middle" fill="url(#goldEmboss)" font-family="'Segoe UI', 'Noto Naskh Arabic', 'Traditional Arabic', serif" font-size="{font_size - 2}" font-weight="700" direction="rtl">{line2}</text>"""
    else:
        title_block = f"""
  <text x="256" y="262" text-anchor="middle" fill="url(#goldEmboss)" font-family="'Segoe UI', 'Noto Naskh Arabic', 'Traditional Arabic', serif" font-size="{font_size}" font-weight="700" direction="rtl">{title_ar}</text>"""

    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="{name_en}">
  <defs>
    <linearGradient id="leather" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#14a06a"/>
      <stop offset="45%" stop-color="#0F8B5F"/>
      <stop offset="100%" stop-color="#0a6848"/>
    </linearGradient>
    <linearGradient id="spine" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0c7550"/>
      <stop offset="100%" stop-color="#085a3d"/>
    </linearGradient>
    <linearGradient id="goldEmboss" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#f5e6b8"/>
      <stop offset="35%" stop-color="#e8c547"/>
      <stop offset="100%" stop-color="#a6851f"/>
    </linearGradient>
    <linearGradient id="pageEdge" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#d4af37"/>
      <stop offset="50%" stop-color="#f5e6b8"/>
      <stop offset="100%" stop-color="#b8891a"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#0f172a" flood-opacity="0.18"/>
    </filter>
    <clipPath id="coverClip">
      <rect x="96" y="72" width="272" height="368" rx="28" ry="28"/>
    </clipPath>
  </defs>

  <!-- white / transparent safe area -->
  <rect width="512" height="512" fill="#ffffff"/>

  <g filter="url(#shadow)">
    <!-- page block + gold edges -->
    <rect x="332" y="88" width="28" height="336" rx="6" fill="url(#pageEdge)"/>
    <rect x="338" y="96" width="3" height="320" rx="1" fill="#fff8dc" opacity="0.35"/>
    <rect x="346" y="96" width="3" height="320" rx="1" fill="#fff8dc" opacity="0.25"/>
    <rect x="354" y="96" width="3" height="320" rx="1" fill="#fff8dc" opacity="0.2"/>

    <!-- spine -->
    <rect x="88" y="72" width="24" height="368" rx="10" fill="url(#spine)"/>

    <!-- cover -->
    <rect x="96" y="72" width="272" height="368" rx="28" ry="28" fill="url(#leather)"/>

    <!-- subtle leather grain -->
    <g clip-path="url(#coverClip)" opacity="0.08">
      <path d="M110 100h240M110 130h220M110 160h230M110 190h210M110 220h240M110 250h200M110 280h230M110 310h215M110 340h225M110 370h205M110 400h235" stroke="#ffffff" stroke-width="1"/>
    </g>

    <!-- gold frame -->
    <rect x="118" y="94" width="248" height="324" rx="20" fill="none" stroke="url(#goldEmboss)" stroke-width="3"/>
    <rect x="128" y="104" width="228" height="304" rx="16" fill="none" stroke="url(#goldEmboss)" stroke-width="1.5" opacity="0.75"/>

    <!-- corner ornaments (original simplified geometry) -->
    <g fill="none" stroke="url(#goldEmboss)" stroke-width="2" opacity="0.9">
      <path d="M132 118h28v28M132 118v28h28"/>
      <path d="M332 118h-28v28M332 118v28h-28"/>
      <path d="M132 394h28v-28M132 394v-28h28"/>
      <path d="M332 394h-28v-28M332 394v-28h-28"/>
    </g>

    <!-- top arch accent -->
    <path d="M156 130 Q256 96 356 130" fill="none" stroke="url(#goldEmboss)" stroke-width="2" opacity="0.55"/>

    <!-- central medallion ring -->
    <circle cx="256" cy="262" r="92" fill="none" stroke="url(#goldEmboss)" stroke-width="1.5" opacity="0.35"/>
    <circle cx="256" cy="262" r="78" fill="none" stroke="url(#goldEmboss)" stroke-width="1" opacity="0.25"/>

    {title_block}

    <!-- bottom seal -->
    <circle cx="256" cy="372" r="14" fill="none" stroke="url(#goldEmboss)" stroke-width="1.5" opacity="0.6"/>
    <path d="M256 360 L262 376 L250 376 Z" fill="url(#goldEmboss)" opacity="0.55"/>

    <!-- bookmark ribbon -->
    <path d="M248 72 L264 72 L256 108 Z" fill="url(#goldEmboss)"/>
    <rect x="252" y="72" width="8" height="46" fill="url(#goldEmboss)" opacity="0.85"/>
  </g>
</svg>
"""


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_books = []
    for order, (slug, name_en, title_ar, fs) in enumerate(BOOKS, start=1):
        path = OUT / f"{slug}.svg"
        path.write_text(svg_for(slug, name_en, title_ar, fs), encoding="utf-8")
        manifest_books.append(
            {
                "slug": slug,
                "name_en": name_en,
                "name_ar": title_ar,
                "icon_file": f"{slug}.svg",
                "sort_order": order,
                "accent": "#0F8B5F",
                "accent_soft": "#ecfdf5",
            }
        )

    manifest = {
        "version": 2,
        "design": "ISLAM 307 premium book icons — original Material 3, inspired by traditional bindings",
        "cover_color": "#0F8B5F",
        "gold": "#C9A227",
        "size": 512,
        "books": manifest_books,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generated {len(BOOKS)} icons -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
