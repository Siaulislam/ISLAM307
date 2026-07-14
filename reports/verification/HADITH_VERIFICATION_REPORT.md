# ISLAM 307 — Hadith Database Verification Report

> **Historical audit / release action:** The audited database, preview packs,
> snapshots and imported source text were removed from release assets on
> 2026-07-14. Hadith screens are permission placeholders.

Generated: 2026-07-11 05:14 UTC

## Executive summary

- **Total hadiths analyzed:** 36,313
- **Database file:** `C:\ISLAM307\app\assets\databases\hadith.db` (247.69 MB)
- **Schema:** v1_legacy_single_grade_column

## 1. Original source of every hadith

- **Recorded builder source (meta):** `fawazahmed0/hadith-api@1`
- **Recorded source URL:** `https://github.com/fawazahmed0/hadith-api`

**Finding:** The bundled `hadith.db` was built from **fawazahmed0/hadith-api@1** (jsdelivr CDN), **not** from Sunnah.com, HadeethEnc.com, Maktaba Shamela authenticated editions, or King Fahd Complex publications.

This is an **unofficial aggregated dataset**. It does **not** meet the project's authenticated-source policy.

## 2. Edition used

Per fawazahmed0/hadith-api References.md, editions vary by book and language:

| Book | Arabic / English editions (as documented by upstream) |
|------|--------------------------------------------------------|
| Sahih Bukhari | Arabic + English (Darussalam-style numbering in API) |
| Sahih Muslim | Arabic + English |
| Abu Dawood | Multiple grading editions from al-maktaba.org (Al-Albani, Arnaout, Abdul Hamid) |
| Tirmidhi | Al-Albani, Ahmed Muhammad Shakir, Bashar Awad Maarouf |
| Nasa'i | Al-Albani, Abu Ghuddah |
| Ibn Majah | Al-Albani, Muhammad Fouad Abd al-Baqi, Arnaout |
| Muwatta Malik | Arabic + English via same API |

**Exact printed edition per hadith is NOT stored in hadith.db.** Only a merged `grade` text field exists.

## 3. Who graded the hadith?

Gradings were **copied from upstream JSON**, which scraped/parsed **al-maktaba.org (Maktaba Shamela web)** grading pages — not directly from Sunnah.com scholars.

Top scholars **documented by upstream** (per book, from al-maktaba.org grading editions):

| Collection | Grading scholars (upstream) |
|------------|----------------------------|
| Sunan Abu Dawood | Al-Albani, Arnaout, Muhammad Muhyi Al-Din Abdul Hamid |
| Jami' at-Tirmidhi | Al-Albani, Ahmed Muhammad Shakir, Bashar Awad Maarouf |
| Sunan an-Nasa'i | Al-Albani, Abu Ghuddah |
| Sunan Ibn Majah | Al-Albani, Muhammad Fouad Abd al-Baqi, Arnaout |
| Sahih Bukhari / Muslim | No per-hadith grade stored in this database (collection assumed Sahih) |
| Muwatta Malik | Mixed grades where present |

**In hadith.db:** Scholar names are **not stored as separate fields**. Grade text often lists classification only (e.g. "Hasan Sahih") without `graded_by`.

## 4. Official scholars vs copied source?

**Copied from another source.** Grades are second-hand aggregations from al-maktaba.org via fawazahmed0's parsing scripts. They are **not** verified directly from Sunnah.com or authenticated Shamela desktop editions.

## 5. Commercial license compatibility

- **Upstream repo license:** The Unlicense (public domain dedication) — permissive for commercial use of the *API wrapper/repo*.
- **Hadith text & grading content:** Islamic texts themselves are generally not copyrightable, but **edition-specific translations** (e.g. Darussalam English) may have publisher rights.
- **Risk:** fawazahmed0 explicitly aggregates from multiple sites without per-edition licensing proof. **Not verified safe for commercial redistribution** of English translations.

**Verdict:** ⚠️ **NOT verified commercial-ready.** Rebuild required from Sunnah.com API (with their terms) or explicitly licensed editions.

## 6. Grade distribution (all hadiths)

| Grade bucket | Count |
|--------------|------:|
| SAHIH | 16,219 |
| UNKNOWN | 15,163 |
| DAIF | 3,256 |
| HASAN | 1,352 |
| OTHER | 257 |
| MAWDU | 66 |

## 7. Data quality

- Missing Arabic text: **401**
- Missing English text: **412**
- Missing any grade: **15,163**
- Missing narrator: **24,283**

## Per-book breakdown

| Book | Hadiths | Sahih | Hasan | Da'if | Other/Unknown |
|------|--------:|------:|------:|------:|--------------:|
| Sahih Bukhari | 7,563 | 0 | 0 | 0 | 7,563 |
| Sahih Muslim | 7,563 | 0 | 0 | 0 | 7,563 |
| Sunan Abu Dawood | 5,274 | 3,749 | 450 | 1,002 | 70 |
| Jami' at-Tirmidhi | 3,956 | 2,844 | 327 | 702 | 66 |
| Sunan an-Nasa'i | 5,758 | 5,095 | 169 | 367 | 127 |
| Sunan Ibn Majah | 4,341 | 3,067 | 350 | 852 | 27 |
| Muwatta Imam Malik | 1,858 | 1,464 | 56 | 333 | 4 |

## Full per-hadith report

Machine-readable JSON with all 36,313 records:

`reports/verification/hadith_full_report.json`

## Recommendation

**DO NOT ship this database in production.** Rebuild using Sunnah.com authenticated API after obtaining an API key.
