# Sanad extraction — connector-word exclusion

## Problem

Narrator names were polluted with transmission connectors, e.g.:

- ❌ `قالت أسماء عن`
- ✅ `أسماء`

## Fix

In `tools/hadith/hadith_meta.py` and `app/lib/features/hadith/hadith_meta.dart`:

1. **`_clean_name_ar`** iteratively strips leading/trailing connector tokens and removes any remaining standalone connectors inside a name.
2. **`_QALA_NAME`** now stops a قال/قالت name at `عن` / next transmission verb (so `قالت أسماء عن …` yields `أسماء`).
3. **Document-order collection** — قال-names and حدثنا/عن-names are merged by text offset (fixes Bukhari 7048 order).

Connectors never kept in names: عن، قال، قالت، قالا، قالوا، يقول، يقولون، ذكر، ذكرت، حدثنا، حدثني، أخبرنا، أخبرني، أنبأنا، سمعت، سمع، نا، ثم، أن، فإن، …

## Validation

Unit tests: `tools/hadith/test_sanad_extraction.py`

| Book | Hadiths scanned | Connector leaks |
|------|-----------------|-----------------|
| bukhari | 7554 | 0 |
| muslim | 7360 | 0 |
| abudawud | 5272 | 0 |
| tirmidhi | 3885 | 0 |
| nasai | 5672 | 0 |
| ibnmajah | 4338 | 0 |
| malik | 1829 | 0 |

Musnad Ahmad is not present in the local hadith DB (7 collections only).

### Canonical examples (all PASS)

1. `عبد الله بن يوسف` → `مالك` → `نافع` → `ابن عمر`
2. `أسماء` → `عائشة`
3. `أبي هريرة`
4. `محمد بن المثنى` → `يحيى` → `شعبة` → `قتادة` → `أنس`
5. Bukhari 7048: `علي بن عبد الله` → `بشر بن السري` → `نافع بن عمر` → `ابن أبي مليكة` → `أسماء`
