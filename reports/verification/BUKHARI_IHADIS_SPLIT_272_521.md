# Bukhari 272–273 & 521–522 — iHadis split fix

## Finding

- **English iHadis** (`/en/bukhari/hadith/{n}`): same full Arabic + English on both numbers (merged A+B).
- **Bangla iHadis** (`/bukhari/hadith/{n}`): correctly splits them.

| Number | Role (per BN iHadis) | Source |
|------:|----------------------|--------|
| 272 | Main ghusl narration | https://ihadis.com/bukhari/hadith/272 |
| 273 | Continuation only (shared vessel) — was full duplicate of 272 | https://ihadis.com/bukhari/hadith/273 |
| 521 | Main prayer-times narration | https://ihadis.com/bukhari/hadith/521 |
| 522 | Continuation only (Aisha / Asr) — was full duplicate of 521 | https://ihadis.com/bukhari/hadith/522 |

## Update rule

- Arabic: exact `text` from BN iHadis JSON-LD (no edits).
- English: exact substrings of EN iHadis merged `workTranslation.text`, cut only at the BN-aligned boundary (`Aisha further said` / `Urwa added`). No new words.

## After update

| # | AR len | EN len | AR source |
|--:|-------:|-------:|-----------|
| 272 | 438 | 361 | https://ihadis.com/bukhari/hadith/272 |
| 273 | 100 | 142 | https://ihadis.com/bukhari/hadith/273 |
| 521 | 968 | 944 | https://ihadis.com/bukhari/hadith/521 |
| 522 | 150 | 161 | https://ihadis.com/bukhari/hadith/522 |

Verified: `text_ar(272) != text_ar(273)` and `text_ar(521) != text_ar(522)` (same for English).
