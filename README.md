# ISLAM 307

**Offline-first Islamic platform** — original premium UI, not a copy of any existing app.

## Status

| Phase | Status |
|-------|--------|
| Flutter UI | License-gated feature routes and offline utilities wired |
| `quran.db` | 6,236 licensed Tanzil Arabic ayahs only |
| Hadith / translations / Tafseer | Permission-pending placeholders; no corpus bundled |
| Flutter Quran module | Surah browse, Arabic reading, personal bookmarks/history/notes |
| Flutter Hadith module | License-status placeholder |
| Flutter Tafsir module | License-status placeholder for permanent offline rights |
| Search + Light/Dark | Wired (ayah, word, root, morphology, juz, page) |
| AI Assistant | Approved local Arabic Quran + user-note search only |
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

Press `Ctrl+C` in the terminal to stop the server.

## Live preview (GitHub Pages — like XMONEY)

**https://siaulislam.github.io/ISLAM307/preview/**

| Page | URL |
|------|-----|
| Preview hub | https://siaulislam.github.io/ISLAM307/preview/ |
| Live library | https://siaulislam.github.io/ISLAM307/preview/library/ |
| Book icons | https://siaulislam.github.io/ISLAM307/preview/icons.html |

Redeploys automatically on every push to `main`.

**If you see 404:** open [Repository Settings → Pages](https://github.com/Siaulislam/ISLAM307/settings/pages) and set:
- **Source:** Deploy from a branch
- **Branch:** `gh-pages` → `/ (root)`
- Save, then wait ~1 minute and refresh.

### Run app
```bash
cd app
flutter pub get
flutter run \
  --dart-define=QF_TOKEN_BROKER_URL=https://your-secure-backend.example/qf-token
```

See [`LICENSE_REQUEST.md`](LICENSE_REQUEST.md), [`LICENSES/`](LICENSES/) and
[`docs/DATASET_LICENSE_TODO.md`](docs/DATASET_LICENSE_TODO.md) for pending
content permissions.

### Rebuild Quran database
```bash
python tools/quran/sanitize_commercial_quran_db.py
```

Output: `app/assets/databases/quran.db`

## quran.db sources

| Data | Source |
|------|--------|
| Arabic Uthmani | Tanzil Project v1.1 (CC BY-ND — unmodified) |

Translations, page/Juz/Ruku metadata, Tajweed and word knowledge remain empty
until their exact licenses permit offline commercial redistribution.

## Tech

Flutter + SQLite · No Firebase · 100% offline

User-generated bookmarks, favorites, notes and history are stored in `user.db`.
Religious content packs are enabled only after passing the dataset license gate.
