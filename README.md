# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Status

| Phase | Status |
|-------|--------|
| UI mockups | Approved (Home buttons open Quran/Hadith/Tafsir) |
| `quran.db` | Built (6,236 ayahs + English + Urdu + word knowledge) |
| `hadith.db` / `tafsir.db` | Bundled; Flutter modules wired |
| Flutter Quran module | Surah/Ruku browse, word-by-word, Urdu/EN/Arabic-only, View Tafsir, audio + TTS |
| Flutter Hadith module | Bukhari · Muslim · Tirmidhi · Abu Dawood |
| Flutter Tafsir module | Source/Surah/Ayah picker · authentic packs only |
| Search + Light/Dark | Wired (ayah, word, root, morphology, juz, page) |
| AI Assistant | Source-only local DB search (never invents) |
| About / Licenses | Data Sources & Licenses acknowledgements |
| Prayer, etc. | Next |

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
| Arabic Uthmani | Tanzil Project v1.1 (CC BY-ND — unmodified) |
| Page, Juz, Ruku, Sajdah, Tajweed | Quran.com API v4 |
| English translation | Sahih International |
| Urdu translation | Maulana Muhammad Junagarhi |
| Word morphology / roots / grammar | Quranic Arabic Corpus v0.4 |
| Word EN/UR meanings | Quran.com word glosses (build-time) |
| 13-line pages | Optional PDF import (not runtime) |

The app reads **quran.db only** — never the PDF. Acknowledgements live in **About → Data Sources & Licenses**.

### Rebuild word knowledge (Phase 4)

```bash
python tools/quran/import_quran_knowledge.py --chapters 1-114
```

## Tech

Flutter + SQLite · No Firebase · 100% offline

Planned DBs: hadith, tafsir, duas, azkar, library, audio, bookmarks, history, notes, usersettings
