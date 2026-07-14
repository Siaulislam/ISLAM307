# ISLAM 307 — Quran database builder

## Sources (verified — not OCR)

| Data | Source |
|------|--------|
| Arabic Uthmani text | [Tanzil Project](https://tanzil.net) v1.1 via dotquran/corpus |
| Page, Juz, Hizb, Ruku, Sajdah | Quran.com API v4 |
| English translation | Saheeh International (resource 20) |
| Urdu translation | Maulana Muhammad Junagarhi (resource 54) |
| Hindi / Filipino / Bengali / Indonesian / Malay / Turkish / Persian / French / Hausa / Somali / Pashto / Swahili | Quran.com API translation resources (see `import_ayah_translations.py`) |
| Tajweed markup | Quran.com `text_uthmani_tajweed` |
| Word morphology / roots / grammar | [Quranic Arabic Corpus](http://corpus.quran.com) morphology v0.4 |
| Word EN/UR glosses + transliteration | Quran.com API word fields (build-time) |

Arabic text is **cross-verified** against the API. On mismatch, **Tanzil text is kept** (authoritative).
Morphology annotations are used **without alteration** (QAC terms).

## Build ayah database

```bash
python tools/quran/build_quran_db.py --skip-pdf
```

Output: `app/assets/databases/quran.db`

## Import offline ayah translations

Downloads **authenticated** translations from Quran.com into `ayahs.translation_<lang>` columns. Never invents or machine-translates text.

```bash
python tools/quran/import_ayah_translations.py
# optional: refresh Urdu as well
python tools/quran/import_ayah_translations.py --include-ur
```

Then re-export the web preview pack:

```bash
python tools/design/export_preview_library.py
```

Selecting a language in the Quran reader shows that language’s exact stored ayah translation under the Arabic.

## Build Phase 4 word knowledge tables

Requires QAC morphology in `tools/quran/cache/` (gitignored). Download once:

```bash
# morphology file is cached as quranic-corpus-morphology-0.4.txt.gz
python tools/quran/import_quran_knowledge.py --chapters 1-114
```

This creates/updates inside `quran.db`:

- `quran_words` — Arabic, EN/UR meaning, root, lemma, POS, morphology, grammar, syntax, occurrences
- `quran_word_parts` — QAC segments
- `quran_words_fts` — offline FTS for Arabic / Urdu / English / root / morphology

Sets `meta.schema_version = 3_knowledge` (importer may later bump to `4_translations_multi`).

Optional: `--skip-api` for morphology-only (no EN/UR glosses).

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

See `schema.sql` — tables: `surahs`, `ayahs`, `juz`, `ruku`, `sajdah`, `pages_madani`, `pages_13_line`, `ayah_fts`.

See `schema_knowledge.sql` — tables: `quran_words`, `quran_word_parts`, `quran_words_fts`.

## Attribution

Required acknowledgements are shown in-app at **About → Data Sources & Licenses** (`assets/modules/data_sources.json`).
