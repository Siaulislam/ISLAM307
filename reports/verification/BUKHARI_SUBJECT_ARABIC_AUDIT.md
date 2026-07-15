# Bukhari subject + Arabic cross-inspection

## Fixed: 6 missing subjects (copied from sunnah.com, no duplicates)

| Hadith | Subject (کتاب) | Sunnah |
|------:|----------------|--------|
| 521 | Book 9 · Times of the Prayers | https://sunnah.com/bukhari:521 |
| 2384 | Book 42 · Distribution of Water | https://sunnah.com/bukhari:2384 |
| 2516 | Book 48 · Mortgaging | https://sunnah.com/bukhari:2516 |
| 2711 | Book 54 · Conditions | https://sunnah.com/bukhari:2711 |
| 3156 | Book 58 · Jizyah and Mawaada'ah | https://sunnah.com/bukhari:3156 |
| 4978 | Book 66 · Virtues of the Qur'an | https://sunnah.com/bukhari:4978 |

Verified: each number has exactly **1** DB row; `chapter_id` set to existing chapter; **0** remaining null subjects in Bukhari.

## Need your detail: missing Arabic (and English) — 9 refs

These DB rows exist with subject already set, but `text_ar` and `text_en` are empty. On sunnah.com they are **combined multi-number** pages (one narration spanning several numbers). I did **not** copy Arabic yet (to avoid inventing/duplicating across numbers). Please send the authenticated Arabic (and English if available) for each:

| Hadith | DB subject | Sunnah page | Combined range |
|------:|------------|-------------|----------------|
| 5710 | Book 76 · Medicine | https://sunnah.com/bukhari:5712 | 5709-5712 |
| 5711 | Book 76 · Medicine | https://sunnah.com/bukhari:5712 | 5709-5712 |
| 5712 | Book 76 · Medicine | https://sunnah.com/bukhari:5712 | 5709-5712 |
| 5774 | Book 76 · Medicine | https://sunnah.com/bukhari:5775 | 5773-5775 |
| 5775 | Book 76 · Medicine | https://sunnah.com/bukhari:5775 | 5773-5775 |
| 6074 | Book 78 · Good Manners and Form (Al-Adab) | https://sunnah.com/bukhari:6075 | 6073-6075 |
| 6075 | Book 78 · Good Manners and Form (Al-Adab) | https://sunnah.com/bukhari:6075 | 6073-6075 |
| 6174 | Book 78 · Good Manners and Form (Al-Adab) | https://sunnah.com/bukhari:6175 | 6173-6175 |
| 6175 | Book 78 · Good Manners and Form (Al-Adab) | https://sunnah.com/bukhari:6175 | 6173-6175 |

### Groups
- **5709–5712** (Medicine): https://sunnah.com/bukhari:5712 — Arabic exists on page; DB empty for 5710, 5711, 5712 (check 5709 too).
- **5773–5775** (Medicine): https://sunnah.com/bukhari:5775 — DB empty for 5774, 5775.
- **6073–6075** (Al-Adab): https://sunnah.com/bukhari:6075 — DB empty for 6074, 6075.
- **6173–6175** (Al-Adab): https://sunnah.com/bukhari:6175 — DB empty for 6174, 6175.

## Clean audit result (Bukhari)
- Total hadiths: **7563** (numbers 1–7563, no gaps, no duplicate numbers)
- Missing subject after fix: **0**
- Missing Arabic: **9** → `[5710, 5711, 5712, 5774, 5775, 6074, 6075, 6174, 6175]`