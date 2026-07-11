# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Status

| Phase | Status |
|-------|--------|
| UI mockups | Approved |
| `quran.db` | Built (6,236 ayahs, Tanzil verified) |
| Flutter app scaffold | Splash, Welcome, Home, Quran reader |
| Hadith, AI, Prayer, etc. | Next |

## Quick start (local Chrome — same as XMONEY)

Double-click or run in PowerShell:

```powershell
C:\ISLAM307\scripts\start-local-preview.ps1
```

Then open in Chrome:

| Page | URL |
|------|-----|
| **Preview hub** | http://localhost:5500/preview/ |
| **Phase 1 mockups (15 screens)** | http://localhost:5500/design/mockups/index.html |
| **Phase 3 mockups (Hadith/Tafsir/AI)** | http://localhost:5500/design/mockups/phase3-mockups.html |

Press `Ctrl+C` in the terminal to stop the server.

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
