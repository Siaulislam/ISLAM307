# Hadith Forensic Audit Report

Generated: `2026-07-12T12:05:48.279213+00:00`

## Policy

- Never invent Arabic, translation, narrator, grade, or reference with AI.
- Every row is cross-checked against authenticated `fawazahmed0/hadith-api@1` editions.
- Manual verification CSV: `reports/verification/HADITH_FORENSIC_AUDIT.csv`

## Overall totals

| Metric | Count |
|--------|------:|
| Total Hadith | **24356** |
| Arabic present | **24071** |
| Arabic absent | **285** |
| Narrator present | **11954** |
| Narrator absent | **12402** |
| Translation present | **24259** |
| Translation absent | **97** |
| Reference present | **24356** |
| Reference absent | **0** |
| Grade present | **9201** |
| Grade absent | **15155** |

## Why Arabic was not imported (explanation of “0 imported”)

Previous quality audit reported `arabic_imported_from_source: 0` because **no empty local rows had Arabic available in the authenticated source to import**. Forensic breakdown:

| Reason | Count |
|--------|------:|
| Arabic already existed in local DB | **24071** |
| Source has no Arabic | **285** |
| Mapping failed (number not in Arabic edition) | **0** |
| Import failed (source has Arabic, local missing) | **0** |

### Reason-code detail

| Code | Count |
|------|------:|
| `ARABIC_ALREADY_EXISTED_MATCHES_SOURCE` | 24071 |
| `SOURCE_HAS_NO_ARABIC` | 285 |

## Per collection

### Sahih Bukhari (`bukhari`)

| Metric | Count |
|--------|------:|
| Total Hadith | **7563** |
| Hadith with Arabic | **7554** |
| Hadith without Arabic | **9** |
| Narrator present | 7403 |
| Narrator absent | 160 |
| Translation present | 7557 |
| Translation absent | 6 |
| Reference present | 7563 |
| Reference absent | 0 |
| Grade present | 0 |
| Grade absent | 7563 |
| Authenticated Arabic edition size | 7563 |
| Authenticated English edition size | 7563 |

**Why Arabic was not imported for this book:**

- Arabic already existed: **7554**
- Source has no Arabic: **9**
- Mapping failed: **0**
- Import failed: **0**

### Sahih Muslim (`muslim`)

| Metric | Count |
|--------|------:|
| Total Hadith | **7563** |
| Hadith with Arabic | **7360** |
| Hadith without Arabic | **203** |
| Narrator present | 5 |
| Narrator absent | 7558 |
| Translation present | 7481 |
| Translation absent | 82 |
| Reference present | 7563 |
| Reference absent | 0 |
| Grade present | 0 |
| Grade absent | 7563 |
| Authenticated Arabic edition size | 7563 |
| Authenticated English edition size | 7563 |

**Why Arabic was not imported for this book:**

- Arabic already existed: **7360**
- Source has no Arabic: **203**
- Mapping failed: **0**
- Import failed: **0**

### Sunan Abu Dawood (`abudawud`)

| Metric | Count |
|--------|------:|
| Total Hadith | **5274** |
| Hadith with Arabic | **5272** |
| Hadith without Arabic | **2** |
| Narrator present | 2953 |
| Narrator absent | 2321 |
| Translation present | 5274 |
| Translation absent | 0 |
| Reference present | 5274 |
| Reference absent | 0 |
| Grade present | 5274 |
| Grade absent | 0 |
| Authenticated Arabic edition size | 5274 |
| Authenticated English edition size | 5274 |

**Why Arabic was not imported for this book:**

- Arabic already existed: **5272**
- Source has no Arabic: **2**
- Mapping failed: **0**
- Import failed: **0**

### Jami' at-Tirmidhi (`tirmidhi`)

| Metric | Count |
|--------|------:|
| Total Hadith | **3956** |
| Hadith with Arabic | **3885** |
| Hadith without Arabic | **71** |
| Narrator present | 1593 |
| Narrator absent | 2363 |
| Translation present | 3947 |
| Translation absent | 9 |
| Reference present | 3956 |
| Reference absent | 0 |
| Grade present | 3927 |
| Grade absent | 29 |
| Authenticated Arabic edition size | 3956 |
| Authenticated English edition size | 3956 |

**Why Arabic was not imported for this book:**

- Arabic already existed: **3885**
- Source has no Arabic: **71**
- Mapping failed: **0**
- Import failed: **0**

## Artifacts for manual verification

- CSV (one row per Hadith): `reports/verification/HADITH_FORENSIC_AUDIT.csv`
- JSON: `reports/verification/HADITH_FORENSIC_AUDIT.json`

CSV columns: Book, Hadith Number, Arabic Present (Yes/No), Narrator Present (Yes/No), Translation Present (Yes/No), Reference Present (Yes/No), Grade Present (Yes/No), Source Provider, Reason if Arabic missing (+ forensic helper columns).
