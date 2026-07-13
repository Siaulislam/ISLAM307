# Arabic Isnad Engine (ISLAM307)

Foundation for the Hadith narrator database. Narrators come **only** from the Sanad.

## Pipeline

1. Split Matn from Sanad (sanad-only cut rules)
2. Split parallel chains on `ح` / `ح وحدثنا` / `ثم حدثنا` / `وحدثنا` (never merge; `وأخبرني` is not parallel)
3. Extract links (`حدثنا` / `أخبرنا` / `عن` / `سمعت` / `أن X أخبره`)
4. Resolve relatives (`أبيه` / `أمه` / `جده` / `أخيه` / `عمه` / `خاله` / `مولاه`) from previous narrator when recoverable
5. Assign permanent **NarratorID** via normalized key (duplicate-safe)
6. Score confidence (0–100); **&lt; 95% → review queue**
7. Store Compiler separately (not a chain link)
8. Append `رسول الله ﷺ` only when Matn *opens* with Prophet speech/action

## Matn terminators (must end Sanad)

`قال/قام/خرج/دخل/كان/بينما/بعث/أتى/جاء/خطب/صلى/نهى/أمر` + رسول الله؛ `قال النبي`؛ `قال: فقام…`؛ `قالت: خرج…`؛ `قال: بينما نحن…`؛ `قال: إذا…`؛ `قال: إن…`

Story characters (هرقل، كسرى، النجاشي، …، رجل، قوم) are **never** narrators.

## Database

`app/assets/databases/isnad.db.gz`

| Table | Role |
|-------|------|
| `compilers` | Collection compilers |
| `narrators` | Permanent IDs + normalized keys |
| `narrator_citations` | Citation-ready bio fields (book/author/volume/page/edition/publisher) |
| `hadith_sanads` | Per-hadith sanad(s) + confidence + review_status |
| `hadith_sanad_links` | Ordered ID chain (+ relative metadata) |
| `sanad_review_queue` | Manual review — only `approved` is production |

## Tests (required before merge)

**No parser update may merge unless all gates pass**, including the Gold Standard.

```bash
bash tools/hadith/tests/run_all_isnad_gates.sh
```

This runs:

1. Unit tests (`test_isnad_engine.py`, `test_isnad_edge_cases.py`) — patterns 1–20, story blocklist, parallel, relatives, nested chains
2. Corpus regression scan (`run_isnad_regression.py`)
3. **Gold Standard** (`run_isnad_gold.py`) — ≥100 verified hadith × Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasai, Ibn Majah
4. Sanad-only verifier (`verify_sanad_only_narrators.py`)

Gold fixtures: `tools/hadith/isnad_engine/gold/*.jsonl`

Collections covered: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah, Malik.  
Musnad Ahmad: same parser (`compilers.ahmad`) when corpus is imported.

## Rebuild

```bash
python3 tools/hadith/isnad_engine/build_isnad_db.py
python3 tools/hadith/isnad_engine/build_gold_standard.py   # only after intentional parser changes
```
