# ISLAM 307 — Tafsir Database Verification Report

> **Historical audit / release action:** The audited Tafseer database and
> preview pack were removed on 2026-07-14. No Tafseer is bundled or streamed
> during normal use; the feature is a permission placeholder.

Generated: 2026-07-11 05:14 UTC

## Executive summary

- **Source:** Tafsir Ibn Kathir (resource_id **169** via api.qurancdn.com)
- **Author:** Ibn Kathir
- **Language:** en
- **Total entries:** 6,009 / 6,236 expected ayahs
- **Coverage:** **96.36%**
- **Complete:** **NO**

## 1. Edition of Tafsir Ibn Kathir

Built from **Quran.com CDN API** (`api.qurancdn.com/api/qdc/tafsirs/169/by_ayah/{surah}:{ayah}`).

This is the **English abridged Tafsir Ibn Kathir** edition distributed by Quran.com / QuranFoundation ecosystem — **not** the full Arabic *Tafsir al-Quran al-Azim*.

Specific print edition metadata (publisher, ISBN, translator name, year) is **NOT stored** in tafsir.db.

## 2. Completeness

- Expected ayahs (114 surahs): **6,236**
- Entries stored: **6,009**
- Missing: **227** ayahs
- Surahs with full coverage: **111 / 114**

**Verdict:** ⚠️ **INCOMPLETE** — 227 ayahs have no tafsir entry (API returned empty or fetch failed).

## 3. Commercial license compatibility

- Data fetched from **Quran.com CDN** without explicit offline redistribution license stored in database.
- Quran.com content is generally offered for apps with attribution, but **commercial offline bundling requires written permission** from QuranFoundation/Quran.com.

**Verdict:** ⚠️ **NOT verified commercial-ready.** Confirm licensing with Quran.com / Darussalam (English Ibn Kathir translator/publisher) before commercial distribution.

## 4. Per-surah coverage

See `reports/verification/tafsir_full_report.json` for full surah-by-surah breakdown.

## Recommendation

Obtain licensed offline Ibn Kathir text or explicit API/dump permission. Re-run builder and store edition metadata in `sources` table.
