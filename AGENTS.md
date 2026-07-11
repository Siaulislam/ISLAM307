# AGENTS.md

## Cursor Cloud specific instructions

This repo (ISLAM 307) has three parts: a Flutter app (`app/`), a static web "Live library" preview (`preview/`), and Python DB-build tools (`tools/`). See `README.md` and `tools/quran/README.md` for the standard commands.

### Flutter app (`app/`)
- Flutter SDK is preinstalled at `/opt/flutter` (added to `PATH` via `~/.bashrc`). If `flutter` is not on `PATH` in a non-interactive shell, call `/opt/flutter/bin/flutter` directly.
- Standard commands (run inside `app/`): `flutter pub get`, `flutter analyze` (lint). There is no `test/` directory, so `flutter test` reports "Test directory not found" — that is expected, not a failure.
- The app cannot run headlessly on web or Linux desktop: the DB layer (`lib/core/database/database_registry.dart`) imports `dart:io` and uses `sqflite` without desktop FFI, so it only targets Android/iOS. Running/emulating the full app requires a mobile emulator/device, which is not available in this VM.
- Known pre-existing issue (not an environment problem): `flutter analyze` reports errors in `lib/features/quran/widgets/ayah_card.dart` because it imports `../../core/...` while the file lives in `widgets/` and needs `../../../core/...`. Other feature files (e.g. `quran_reader_screen.dart`) import correctly.

### Runnable demo: static preview library (`preview/`)
- This is the app that actually runs in this VM. Serve the repo root and open the library:
  - `python3 -m http.server 5500 --bind 127.0.0.1` (from repo root)
  - Open `http://127.0.0.1:5500/preview/library/index.html` — Quran / Hadith / Tafsir tabs read the committed JSON under `preview/library/data/`.
- Note: not every ayah has a Tafsir entry (e.g. try Surah 2 Ayah 255); missing entries show a handled "No authentic tafsir entry" message, which is expected.

### Python tools (`tools/`)
- Pure stdlib (no `pip` requirements); `pymupdf` is optional and only used for PDF page mapping (skipped with `--skip-pdf`).
- The `build_*_db.py` scripts fetch from external APIs (Quran.com, Tanzil, sunnah.com) and need internet; the built databases are already committed under `app/assets/databases/`, so rebuilding is not required for normal development.
