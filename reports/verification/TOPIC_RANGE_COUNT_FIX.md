# Topic card range vs count discrepancy

## Bug (user screenshot)

Card showed:

- Title: **Sahih Bukhari** (collection name, not a کتاب)
- Range: **Hadith 521 to 4978**
- Count: **6 Hadith**

## Cause

Six Bukhari hadiths (`521, 2384, 2516, 2711, 3156, 4978`) have `chapter_id = NULL` in the authenticated source (edition section `0` / uncategorized).

The topic UI fell back to the **book name** as the topic title and used `min–max` as if it were a continuous block.

## Fix

1. Never use the collection name as a topic title.
2. Bucket missing-chapter hadiths as **Unassigned** (source-uncategorized).
3. Range label is density-aware:
   - dense chapters → `Hadith X to Y`
   - sparse / unassigned → list numbers (e.g. `Hadith 521, 2384, 2516, 2711, 3156, 4978`)
4. Same honesty rules in Flutter topic cards; Unassigned is openable in the reader.

## Validation

Preview packs (bukhari / muslim / abudawud / tirmidhi): **0** remaining “X to Y with count ≪ span” discrepancies after the fix.

Bukhari Unassigned: `Hadith 521, 2384, 2516, 2711, 3156, 4978` · count 6.
