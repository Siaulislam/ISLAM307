# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Phase 1: UI Mockups (current)

Review all screens before development begins:

```
design/mockups/index.html   ← Open in browser (Chrome recommended)
```

## Design system

| Token | Value | Usage |
|-------|-------|--------|
| Background | `#FFFFFF` | Primary surface |
| Emerald | `#0D9488` | Primary actions, accents |
| Emerald deep | `#065F46` | Headers, emphasis |
| Gold | `#C9A227` | Highlights, badges, ornaments |
| Gold light | `#F5E6B8` | Subtle fills |
| Text primary | `#0F172A` | Body, titles |
| Text muted | `#64748B` | Secondary labels |
| Card shadow | `0 4px 24px rgba(15,23,42,0.08)` | Elevated cards |
| Radius | `16px` / `20px` | Cards, buttons |

## Tech stack (Phase 2 — after UI approval)

- Flutter (mobile + web)
- SQLite only — no Firebase, no internet required
- Separate databases: quran, hadith, tafsir, duas, azkar, library, audio, bookmarks, history, notes, usersettings

## Status

- [x] UI mockup gallery (all screens)
- [ ] UI approval
- [ ] Project scaffold
- [ ] Database schema & Quran PDF → SQLite pipeline
- [ ] Module development
