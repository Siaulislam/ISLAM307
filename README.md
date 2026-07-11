# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Status

| Phase | Status |
|-------|--------|
| UI mockups | Approved |
| `quran.db` | Built (6,236 ayahs, Tanzil verified) |
| Flutter app scaffold | Splash, Welcome, Home, Quran reader |
| Hadith, AI, Prayer, etc. | Next |

## Quick start

### UI mockups
Open `design/mockups/index.html` in Chrome.

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
