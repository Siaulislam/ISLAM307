# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Status

| Phase | Status |
|-------|--------|
| UI mockups | Approved (Home buttons open Quran/Hadith/Tafsir) |
| `quran.db` | Built (6,236 ayahs + English + Urdu Junagarhi) |
| `hadith.db` / `tafsir.db` | Bundled; Flutter modules wired |
| Flutter Quran module | Surah/Ruku browse, Urdu/EN/Arabic-only, View Tafsir, audio |
| Flutter Hadith module | Bukhari · Muslim · Tirmidhi · Abu Dawood |
| Flutter Tafsir module | Source/Surah/Ayah picker · authentic packs only |
| Search + Light/Dark | Wired |
| Flutter Qibla | Live GPS + offline Kaaba bearing |
| Flutter Prayer | Live GPS + offline timetable |
| AI, Azkar, etc. | Next |

## Quick start (local Chrome — same as XMONEY)

Double-click or run in PowerShell:

```powershell
C:\ISLAM307\scripts\start-local-preview.ps1
```

Then open in Chrome:

| Page | URL |
|------|-----|
| **Preview hub** | http://localhost:5500/preview/ |
| **Live library (Quran/Hadith/Tafsir)** | http://localhost:5500/preview/library/ |
| **Phase 1 mockups (15 screens)** | http://localhost:5500/design/mockups/index.html |
| **Phase 3 mockups (Hadith/Tafsir/AI)** | http://localhost:5500/design/mockups/phase3-mockups.html |

Press `Ctrl+C` in the terminal to stop the server.

## Live preview (GitHub Pages — like XMONEY)

**https://siaulislam.github.io/ISLAM307/preview/**

| Page | URL |
|------|-----|
| Preview hub | https://siaulislam.github.io/ISLAM307/preview/ |
| Live library | https://siaulislam.github.io/ISLAM307/preview/library/ |
| Phase 1 mockups | https://siaulislam.github.io/ISLAM307/design/mockups/index.html |
| Phase 3 mockups | https://siaulislam.github.io/ISLAM307/design/mockups/phase3-mockups.html |
| Book icons | https://siaulislam.github.io/ISLAM307/preview/icons.html |

Redeploys automatically on every push to `main`.

**If you see 404:** open [Repository Settings → Pages](https://github.com/Siaulislam/ISLAM307/settings/pages) and set:
- **Source:** Deploy from a branch
- **Branch:** `gh-pages` → `/ (root)`
- Save, then wait ~1 minute and refresh.

### UI mockups (file path alternative)
Open `design/mockups/index.html` directly in Chrome if you prefer.

### Run app
```bash
cd app
flutter pub get
flutter run
```

### Rebuild Quran database
```bash
python tools/quran/build_quran_db.py --skip-pdf
```

Output: `app/assets/databases/quran.db`

## quran.db sources

| Data | Source |
|------|--------|
| Arabic Uthmani | Tanzil Project v1.1 |
| Page, Juz, Ruku, Sajdah, Tajweed | Quran.com API v4 |
| English translation | Sahih International |
| 13-line pages | Optional PDF import (not runtime) |

The app reads **quran.db only** — never the PDF.

## Tech

Flutter + SQLite · No Firebase · 100% offline

Planned DBs: hadith, tafsir, duas, azkar, library, audio, bookmarks, history, notes, usersettings
