# Narrator Rebuild Report

Generated: `2026-07-12T12:26:10.461019+00:00`

## Policy

- Never invent narrator names with AI.
- Import only from authenticated Sunni editions (`fawazahmed0/hadith-api@1`).
- If a narrator cannot be verified from authenticated English or Arabic isnad, leave empty.

## Exact recovery totals

| Metric | Count |
|--------|------:|
| Total Hadith | **24356** |
| Narrators present BEFORE rebuild | **11954** |
| Narrators present AFTER rebuild | **24055** |
| Narrators still missing (unverifiable) | **301** |
| **Newly recovered** | **12101** |
| Kept existing (same authenticated value) | 11035 |
| Replaced with authenticated value | 919 |
| Cleared (could not re-verify) | 0 |

### Extraction methods (authenticated text only)

| Method | Count |
|--------|------:|
| `en:narrated_colon` | 11926 |
| `ar:arabic_isnad_companion` | 2352 |
| `en:x_reported_colon` | 1813 |
| `en:x_said_colon` | 1662 |
| `en:x_reported_that` | 1465 |
| `en:x_narrated_that` | 1022 |
| `en:x_reported_messenger` | 982 |
| `en:this_hadith_auth` | 859 |
| `en:x_narrated_colon` | 633 |
| `en:x_reported_auth` | 291 |
| `en:this_hadith_by` | 230 |
| `en:it_has_been_auth` | 229 |
| `en:last_on_authority` | 203 |
| `en:auth_narrated` | 181 |
| `en:x_narrated_auth` | 96 |
| `en:auth_reported` | 56 |
| `en:x_honor_reported` | 30 |
| `en:it_was_from` | 19 |
| `en:it_was_that` | 6 |

## Per collection

### Sahih Bukhari (`bukhari`)

| Metric | Count |
|--------|------:|
| Total | 7563 |
| Before present / missing | 7403 / 160 |
| After present / missing | **7547** / **16** |
| Newly recovered | **144** |
| Replaced with authenticated | 272 |
| Cleared unverified | 0 |

### Sahih Muslim (`muslim`)

| Metric | Count |
|--------|------:|
| Total | 7563 |
| Before present / missing | 5 / 7558 |
| After present / missing | **7358** / **205** |
| Newly recovered | **7353** |
| Replaced with authenticated | 1 |
| Cleared unverified | 0 |

### Sunan Abu Dawood (`abudawud`)

| Metric | Count |
|--------|------:|
| Total | 5274 |
| Before present / missing | 2953 / 2321 |
| After present / missing | **5270** / **4** |
| Newly recovered | **2317** |
| Replaced with authenticated | 269 |
| Cleared unverified | 0 |

### Jami' at-Tirmidhi (`tirmidhi`)

| Metric | Count |
|--------|------:|
| Total | 3956 |
| Before present / missing | 1593 / 2363 |
| After present / missing | **3880** / **76** |
| Newly recovered | **2287** |
| Replaced with authenticated | 377 |
| Cleared unverified | 0 |

## Notes

- “Recovered” means a narrator string was written into `hadiths.narrator` from authenticated source text.
- Remaining empties are cases where the authenticated edition has no extractable narrator (empty text, “Narrator not mentioned”, chain-only comments, etc.).
- Follow-up forensic CSV: `HADITH_FORENSIC_AUDIT_NARRATORS.csv`
