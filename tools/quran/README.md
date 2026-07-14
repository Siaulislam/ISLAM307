# Commercially cleared Quran package

The release database contains only:

- Tanzil Project Uthmani Arabic text v1.1
- Surah/Ayah numbering and basic Surah identity
- CC BY-ND 3.0 attribution metadata

Translations, Quran.com structural metadata, Tajweed markup, PDFs and Quranic
Arabic Corpus word knowledge are not imported while their permanent offline
commercial rights remain pending.

Sanitize an existing development database:

```bash
python tools/quran/sanitize_commercial_quran_db.py
```

Then run the release gate:

```bash
python tools/verification/check_dataset_license_gate.py
```

See `LICENSES/quran-arabic-tanzil.md`, `LICENSES/quran-translations.md`,
`LICENSES/quranic-arabic-corpus.md`, and `LICENSE_REQUEST.md`.
