# Bukhari Arabic duplicates — iHadis verification

Source: [`https://ihadis.com/en/bukhari/hadith/{n}`](https://ihadis.com/en/bukhari/hadith/1) (JSON-LD `text` / `workTranslation`).

> Note: `ihadith.com` is a parked domain. This project uses **ihadis.com**.

## Policy

- If iHadis also has the same Arabic on multiple numbers → **keep the duplicates**.
- Update our DB **only** to match iHadis exactly.
- No invented text, no merges/deletes of records, no AI splits.

## Verification result

- Checked **604** hadith numbers from the duplicate report (+ 272/273/521/522).
- iHadis also has **identical Arabic within all 292 duplicate groups** (0 groups split differently on EN iHadis).
- Rows updated to match iHadis: **595** (AR changed: 531, EN changed: 595).
- Of Arabic updates: **508** were Unicode NFC encoding-only; content/length changes: **23** → `[272, 273, 521, 522, 896, 897, 1931, 1932, 3252, 3253, 3495, 3496, 3587, 3588, 3589, 4246, 4247, 4305, 4306, 4978, 4979, 6825, 6826]`.

## Restored pairs (previous incorrect split)

EN iHadis shows the **same full Arabic** on both numbers. BN iHadis splits them, but per policy we follow EN iHadis duplicates as-is:

| Pair | Action |
|------|--------|
| 272–273 | Restored to identical iHadis EN Arabic/English |
| 521–522 | Restored to identical iHadis EN Arabic/English |

## Post-update duplicate counts

- Exact Arabic duplicate groups: **294**
- Hadiths involved: **604**

These duplicates are retained because they match iHadis.
