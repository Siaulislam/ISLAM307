# Hadith Quality Audit Report

Generated: `2026-07-12T11:49:37.109546+00:00`

## Policy

- Never invent Arabic, translation, narrator, grade, or reference with AI.
- Cross-check only against authenticated source editions.
- If Arabic is missing in the authenticated source, leave it empty.

**Source checked:** `fawazahmed0/hadith-api@1 (same provenance as current hadith.db)`

## Totals

- Total Hadith checked: **24356**
- Arabic imported from authenticated source: **0**
- Non-Arabic placeholders cleared from text_ar: **2**
- Narrators corrected from authenticated English: **0**
- References corrected (URL + provider): **24356**
- Missing authenticated Arabic (empty in source too): **283**

## Per book

### Sahih Bukhari (`bukhari`)

- Total: 7563
- Arabic imported: 0
- Arabic cleared (non-Arabic script): 0
- Narrators corrected: 0
- References corrected: 7563
- Missing authenticated Arabic: 9
- Logged mismatch actions: 0

### Sahih Muslim (`muslim`)

- Total: 7563
- Arabic imported: 0
- Arabic cleared (non-Arabic script): 0
- Narrators corrected: 0
- References corrected: 7563
- Missing authenticated Arabic: 203
- Logged mismatch actions: 0

### Sunan Abu Dawood (`abudawud`)

- Total: 5274
- Arabic imported: 0
- Arabic cleared (non-Arabic script): 0
- Narrators corrected: 0
- References corrected: 5274
- Missing authenticated Arabic: 2
- Logged mismatch actions: 0

### Jami' at-Tirmidhi (`tirmidhi`)

- Total: 3956
- Arabic imported: 0
- Arabic cleared (non-Arabic script): 2
- Narrators corrected: 0
- References corrected: 3956
- Missing authenticated Arabic: 69
- Logged mismatch actions: 2

## Notes

- UI shows “Arabic text unavailable in authenticated source.” only when Arabic is truly empty after this audit.
- A future Sunnah.com API rebuild (with API key) remains the preferred long-term primary source migration.
