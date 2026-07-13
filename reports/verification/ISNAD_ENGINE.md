# Arabic Isnad Engine (ISLAM307)

Foundation for the Hadith narrator database. Narrators come **only** from the Sanad.

## Pipeline

1. Split Matn from Sanad (sanad-only cut rules)
2. Split parallel chains on `ح` / `ح وحدثنا` (never merge)
3. Extract links (`حدثنا` / `أخبرنا` / `عن` / `سمعت` / `أن X أخبره`)
4. Resolve relatives (`أبيه` …) from previous narrator when recoverable
5. Assign permanent **NarratorID** via normalized key (duplicate-safe)
6. Score confidence (0–100); **&lt; 95% → review queue**
7. Store Compiler separately (not a chain link)

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

```bash
python3 -m unittest tools.hadith.tests.test_isnad_engine -v
python3 tools/hadith/tests/run_isnad_regression.py
python3 tools/hadith/verify_sanad_only_narrators.py
```

Collections covered: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah, Malik.  
Musnad Ahmad: same parser (`compilers.ahmad`) when corpus is imported.

## Rebuild

```bash
python3 tools/hadith/isnad_engine/build_isnad_db.py
```
