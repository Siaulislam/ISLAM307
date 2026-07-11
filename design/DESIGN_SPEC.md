# ISLAM 307 — Design Specification

## Brand identity

- **Name:** ISLAM 307
- **Logo:** Geometric emerald tile with "307" + "ISLAM" wordmark
- **Tone:** Premium, calm, scholarly, trustworthy
- **Not inspired by:** Islam360 or any clone — original layout and visual language only

## Color palette

| Name | Hex | Use |
|------|-----|-----|
| White | `#FFFFFF` | Primary background |
| Emerald | `#0D9488` | Primary buttons, active states |
| Emerald Deep | `#065F46` | Headings, emphasis |
| Emerald Soft | `#ECFDF5` | Card fills, prayer highlight |
| Gold | `#C9A227` | Accents, badges, card top border |
| Gold Light | `#F5E6B8` | Borders, ornaments |
| Text | `#0F172A` | Primary text |
| Muted | `#64748B` | Secondary text |

## Typography

- **UI:** Segoe UI / SF Pro / system sans-serif
- **Arabic Quran:** Traditional Arabic / Amiri / Scheherazade (Uthmani 13-line)
- **Urdu:** Noto Nastaliq Urdu (when Urdu selected)

## Screen inventory (15 mockups)

1. Splash — logo animation, geometric pattern
2. Welcome — language + Get Started / Guest
3. Home Dashboard — verse, prayer, quick grid, continue reading
4. Quran Surah list — search, juz/page tabs
5. Quran Reader — Uthmani, tools, translation, word meaning
6. Hadith — 7 books list
7. Tafsir — professional reading
8. AI Assistant — source-only answers with references
9. Prayer — times, qibla, tasbeeh, hijri
10. Library — categories + books
11. Audio — player + reciters
12. Videos — future placeholder
13. Downloads — manage offline packs
14. Settings — theme, language, backup
15. More — secondary navigation

## Bottom navigation

Home · Quran · AI · Library · More

## AI rules (critical)

- NEVER generate Islamic rulings from model knowledge alone
- Search ONLY: Quran.db, Hadith.db, Tafsir.db
- Every answer MUST cite: Surah/Ayah OR Hadith Book/Number OR Tafsir name
- Fallback: **"No authentic reference found."**

## Database plan (Phase 2)

| Database | Purpose |
|----------|---------|
| quran.db | 13-line Uthmani, translation, search, pages, juz |
| hadith.db | 7 collections |
| tafsir.db | Tafsir texts linked to ayah |
| duas.db | Supplications |
| azkar.db | Remembrance |
| library.db | Islamic books |
| audio.db | Reciter metadata + file paths |
| bookmarks.db | User bookmarks |
| history.db | Reading history |
| notes.db | User notes on ayah |
| usersettings.db | Theme, language, font, location |

## Quran PDF → SQLite pipeline (Phase 2)

User provides 13-line Quran PDF. Process:

1. OCR / extract structured text per ayah
2. Map page numbers, juz, surah
3. Add translation + search keywords
4. Store in quran.db — app NEVER reads PDF at runtime

## Next step

**Awaiting UI approval.** Reply with changes or "approved" to begin Flutter + SQLite development.
