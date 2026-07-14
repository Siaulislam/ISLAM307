# Sunnah.com Narrator Fill (Content-Verified)

Generated: `2026-07-12T13:12:42.893373+00:00`

## Policy

- Copied ravi names from **sunnah.com** only.
- Verified **same book** and **same hadith text** (English/Arabic fingerprint) before import.
- Did **not** trust hadith number alone (Muslim numbering especially can diverge).
- If sunnah.com page had no extractable ravi, or content could not be matched → left empty.

## Results

| Metric | Count |
|--------|------:|
| Originally missing after rebuild | 301 |
| Filled from sunnah.com (content-verified) | **13** |
| Still missing | **288** |

### Still missing by book

| Book | Missing |
|------|--------:|
| `abudawud` | 2 |
| `bukhari` | 9 |
| `muslim` | 205 |
| `tirmidhi` | 72 |

### Why most remain empty

- **Sahih Muslim (~205):** many local rows have empty English/Arabic (Urdu-only or blank). Sunnah.com URLs with the same number often belong to a **different** hadith body (e.g. local Introduction vs sunnah Book of Faith). Without matching text, ravi was **not** copied.
- **Tirmidhi / Bukhari blanks:** authenticated edition has empty AR/EN, or sunnah page itself has no `Narrated` label / isnad links (continuation notes, “Narrator not mentioned”, empty slots).
- Never invented names.

## Content-verified imports

| Book | # | Narrator |
|------|--:|----------|
| Sunan Abu Dawood | 123 | Al-Miqdam b. Ma’dikarib |
| Sunan Abu Dawood | 1598 | Waki' |
| Sahih Bukhari | 239 | Abu Huraira |
| Sahih Bukhari | 486 | نافع |
| Sahih Bukhari | 804 | أبو هريرة الدوسي |
| Sahih Bukhari | 1848 | Ya'li |
| Sahih Bukhari | 5337 | Zainab |
| Sahih Bukhari | 5956 | Aisha |
| Sahih Bukhari | 6625 | Abu Huraira |
| Jami' at-Tirmidhi | 225 | أبو هريرة الدوسي |
| Jami' at-Tirmidhi | 319 | أنس بن مالك الأنصاري |
| Jami' at-Tirmidhi | 1227 | Ibn 'Umar |
| Jami' at-Tirmidhi | 2498 | Al-Harith bin Suwaid |

## CSV artifacts

- `reports/verification/SUNNAH_CONTENT_VERIFIED_NARRATORS.csv`
- `reports/verification/MISSING_NARRATORS_REMAINING.csv` (manual follow-up list)
