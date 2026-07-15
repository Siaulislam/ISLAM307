# Sanad Extraction: Prophet ﷺ Cutoff Rule

## Rule
In every Hadith, all personal names from the beginning of the Arabic text until the **first** mention of the Prophet ﷺ are narrators (Rawis).

Stop at the first of:
- النبي صلى الله عليه وسلم
- رسول الله صلى الله عليه وسلم
- محمد صلى الله عليه وسلم
(and common orthographic / ﷺ variants)

The Prophet ﷺ is **not** a narrator. Everything after is Matn.

## Implementation
- `tools/hadith/hadith_meta.py` — `_cut_isnad_ar`, `_extract_names_from_ar_isnad`
- `app/lib/features/hadith/hadith_meta.dart` — Dart parity

## Fixes vs previous logic
- Bare `محمد` is **not** treated as the Prophet (so chains like … عن محمد، عن ابن أبي بكرة … are complete).
- Primary cut is the first Prophet ﷺ marker (not early matn heuristics alone).
- No fixed 16-narrator cap.
- Example hadith (Bukhari 105 style) extracts all 6 narrators through أبي بكرة.

## Regenerated
- Knowledge packs `bukhari-59` … `bukhari-134`
- All Bukhari preview `ravi_chain` / `ravi_by_lang` fields
