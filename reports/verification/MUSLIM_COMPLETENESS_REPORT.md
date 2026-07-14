# Sahih Muslim Completeness Report (updated after sunnah fill)

- **Book:** Sahih Muslim (`muslim`)
- **Total hadith rows in DB:** 7565
- **Complete (AR + EN + UR):** 7458
- **Incomplete (any language missing):** 107

## Summary

| Language | Missing count |
|---|---:|
| Arabic | 107 |
| English | 107 |
| Urdu | 45 |
| Empty in all three | 45 |

## Latest fill from sunnah.com

- AR/EN filled from sunnah in-book pages: **7**
- Urdu filled from English translation: **23**
- Remaining gap slots with no sunnah mapping (empty in 7563 scheme): **107**

### Important about remaining gaps

These local numbers are **empty placeholders** in the 7563 numbering scheme (same empties as authenticated fawaz ara/eng editions).
Their sunnah.com content already exists under other local numbers via `arabic_number` (example: local gap `128` content is at local `334` / arabic `128.01`).
Copying `sunnah.com/muslim:{gap}` into the gap slot would duplicate the wrong row mapping.

- Gap slots that already have content elsewhere: **24**

Examples:
- gap `128` → already at 334 (arabic 128.01), 335 (arabic 128.02)
- gap `209` → already at 510 (arabic 209.01), 511 (arabic 209.02), 512 (arabic 209.03)
- gap `248` → already at 583 (arabic 248)
- gap `637` → already at 1441 (arabic 637.01), 1442 (arabic 637.02)
- gap `638` → already at 1443 (arabic 638.01), 1444 (arabic 638.02), 1445 (arabic 638.03)
- gap `794` → already at 1853 (arabic 794.01), 1854 (arabic 794.02), 1855 (arabic 794.03)
- gap `852` → already at 1969 (arabic 852.01), 1970 (arabic 852.02), 1971 (arabic 852.03), 1972 (arabic 852.04), 1973 (arabic 852.05), 1974 (arabic 852.06)
- gap `853` → already at 1975 (arabic 853)
- gap `881` → already at 2036 (arabic 881.01), 2037 (arabic 881.02), 2038 (arabic 881.03)
- gap `1221` → already at 2957 (arabic 1221.01), 2958 (arabic 1221.02), 2959 (arabic 1221.03), 2960 (arabic 1221.04)
- gap `1222` → already at 2961 (arabic 1222)
- gap `1332` → already at 3239 (arabic 1332)
- gap `1351` → already at 3294 (arabic 1351.01), 3295 (arabic 1351.02), 3296 (arabic 1351.03)
- gap `1355` → already at 3305 (arabic 1355.01), 3306 (arabic 1355.02)
- gap `1366` → already at 3323 (arabic 1366)

## Missing Arabic

- **Count:** 107
- **Ranges:** 128, 209, 248, 637–638, 794, 852–853, 881, 1221–1222, 1251, 1332, 1351, 1355, 1366, 1428–1429, 1648, 1719, 1778, 2295, 2339, 2381, 2810, 3038–3039, 3262, 3463, 3525, 3836, 3845, 4436, 5214, 5384, 5393, 5541–5545, 5637, 5995–6003, 6144, 6527–6529, 6701–6702, 6792, 6844–6845, 7016, 7020, 7144, 7256, 7301, 7325, 7329–7343, 7371, 7447–7463, 7513–7519, 7557

## Missing English

- **Count:** 107
- **Ranges:** 128, 209, 248, 637–638, 794, 852–853, 881, 1221–1222, 1251, 1332, 1351, 1355, 1366, 1428–1429, 1648, 1719, 1778, 2295, 2339, 2381, 2810, 3038–3039, 3262, 3463, 3525, 3836, 3845, 4436, 5214, 5384, 5393, 5541–5545, 5637, 5995–6003, 6144, 6527–6529, 6701–6702, 6792, 6844–6845, 7016, 7020, 7144, 7256, 7301, 7325, 7329–7343, 7371, 7447–7463, 7513–7519, 7557

## Missing Urdu

- **Count:** 45
- **Ranges:** 5541–5545, 5996–6003, 7016, 7020, 7331–7343, 7447–7463

## Incomplete chapters

| Chapter | Title | Missing AR | Missing EN | Missing UR |
|---:|---|---:|---:|---:|
| 55 | The Book of Zuhd and Softening of Hearts  | 24 | 24 | 17 |
| 54 | The Book of Tribulations and Portents of the Last Hour | 19 | 19 | 13 |
| 43 | The Book of Virtues | 11 | 11 | 8 |
| 5 | The Book of Mosques and Places of Prayer | 9 | 9 | 0 |
| 37 | The Book of Clothes and Adornment | 6 | 6 | 5 |
| 45 | The Book of Virtue, Enjoining Good Manners, and Join… | 5 | 5 | 0 |
| 15 | The Book of Pilgrimage | 4 | 4 | 0 |
| 1 | The Book of Faith | 3 | 3 | 0 |
| 4 | The Book of Prayers  | 3 | 3 | 0 |
| 6 | The Book of Prayer - Travellers | 3 | 3 | 0 |
| 12 | The Book of Zakat | 3 | 3 | 0 |
| 50 | The Book of Repentance | 2 | 2 | 2 |
| 2 | The Book of Purification | 2 | 2 | 0 |
| 16 | The Book of Marriage | 2 | 2 | 0 |
| 21 | The Book of Transactions | 2 | 2 | 0 |
| 48 | The Book Pertaining to the Remembrance of Allah, Sup… | 2 | 2 | 0 |
| 3 | The Book of Menstruation | 1 | 1 | 0 |
| 29 | The Book of Legal Punishments | 1 | 1 | 0 |
| 36 | The Book of Drinks | 1 | 1 | 0 |
| 38 | The Book of Manners and Etiquette | 1 | 1 | 0 |
| 47 | The Book of Knowledge | 1 | 1 | 0 |
| 53 | The Book of Paradise, its Description, its Bounties … | 1 | 1 | 0 |
| 56 | The Book of Commentary on the Qur'an | 1 | 1 | 0 |
