# ISLAM 307 — Quran database builder

## Sources (verified — not OCR)

| Data | Source |
|------|--------|
| Arabic Uthmani text | [Tanzil Project](https://tanzil.net) v1.1 via dotquran/corpus |
| Page, Juz, Hizb, Ruku, Sajdah | Quran.com API v4 |
| English translation | Sahih International (resource 131) |
| Tajweed markup | Quran.com `text_uthmani_tajweed` |

Arabic text is **cross-verified** against the API. On mismatch, **Tanzil text is kept** (authoritative).

## Build

```bash
python tools/quran/build_quran_db.py --skip-pdf
```

Output: `app/assets/databases/quran.db`

## Optional 13-line PDF page mapping

Place your 13-line mushaf PDF at:

```
data/source/quran-13-line.pdf
```

Then run:

```bash
pip install pymupdf
python tools/quran/build_quran_db.py
```

The PDF is used **only** to map `page_13_line` numbers by detecting `surah:ayah` markers and aligning to verified text. The app **never** reads the PDF at runtime.

## Schema

See `schema.sql` — tables: `surahs`, `ayahs`, `juz`, `ruku`, `sajdah`, `pages_madani`, `pages_13_line`, `ayah_fts` (FTS5 full-text search).
