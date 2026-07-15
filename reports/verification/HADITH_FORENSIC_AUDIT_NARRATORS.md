# Hadith Forensic Audit — Narrators (Second Report)

Generated: `2026-07-12T12:27:07.436438+00:00`

## Policy

- Never invent narrator names with AI.
- Every stored narrator re-checked against authenticated English + Arabic editions.
- If unverifiable in authenticated source text → empty.

## Narrators recovered (from rebuild)

| Metric | Count |
|--------|------:|
| Newly recovered narrators | **12101** |
| Present before rebuild | 11954 |
| Present after rebuild | **24055** |
| Still missing (unverifiable) | **301** |

## Post-rebuild verification

| Metric | Count |
|--------|------:|
| Total Hadith | **24356** |
| Narrator present | **24055** |
| Narrator absent | **301** |
| Verified match (DB == authenticated extraction) | **24055** |
| Mismatch | **0** |
| Missing & unverifiable in source | **301** |
| Missing but source has extractable narrator | **0** |

## Per collection

### Sahih Bukhari (`bukhari`)

| Metric | Count |
|--------|------:|
| Total | 7563 |
| Narrator present | **7547** |
| Narrator absent | **16** |
| Verified match | 7547 |
| Mismatch | 0 |
| Missing unverifiable | 16 |
| Missing but source has | 0 |

### Sahih Muslim (`muslim`)

| Metric | Count |
|--------|------:|
| Total | 7563 |
| Narrator present | **7358** |
| Narrator absent | **205** |
| Verified match | 7358 |
| Mismatch | 0 |
| Missing unverifiable | 205 |
| Missing but source has | 0 |

### Sunan Abu Dawood (`abudawud`)

| Metric | Count |
|--------|------:|
| Total | 5274 |
| Narrator present | **5270** |
| Narrator absent | **4** |
| Verified match | 5270 |
| Mismatch | 0 |
| Missing unverifiable | 4 |
| Missing but source has | 0 |

### Jami' at-Tirmidhi (`tirmidhi`)

| Metric | Count |
|--------|------:|
| Total | 3956 |
| Narrator present | **3880** |
| Narrator absent | **76** |
| Verified match | 3880 |
| Mismatch | 0 |
| Missing unverifiable | 76 |
| Missing but source has | 0 |

## Manual verification CSV

`reports/verification/HADITH_FORENSIC_AUDIT_NARRATORS.csv` — one row per Hadith.

Columns include Book, Hadith Number, Narrator Present, Narrator Value, Authenticated Extraction, Extraction Method, Verification Status, Reason.
