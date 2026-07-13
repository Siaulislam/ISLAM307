# Offline Quran translation — availability & license audit

**App policy:** 100% free · Sadaqah Jariyah · offline-first · never invent or machine-translate Quran text.

**Checked:** 2026-07-13 against Quran.com API resource list, Quran Foundation Developer Terms, and Tanzil translation terms.

## Offline languages currently in `quran.db`

| Lang | Offline ayahs | Translator / source | Quran.com id | License status |
|------|--------------:|---------------------|-------------:|----------------|
| **en** | 6236 | Saheeh International | 20 | **Attribution required.** Common in free Islamic apps. Tanzil redistributes similar text as **non-commercial** unless translator/publisher permission is obtained. |
| **ur** | 6236 | Maulana Muhammad Junagarhi | 54 | **Attribution required.** Same non-commercial caution via Tanzil-style redistribution norms. |
| **hi** | 6236 | Maulana Azizul Haque al-Umari | 122 | **Attribution required.** No separate public license on Quran.com resource metadata — treat as **permission needed for commercial store redistribution**. |
| **fil** | 6236 | Dar Al-Salam Center (Tagalog) | 211 | **Attribution required.** Permission recommended for commercial redistribution. |
| **bn** | 6236 | Taisirul Quran / Tawheed Publication | 161 | **Attribution required.** Permission recommended for commercial redistribution. |
| **id** | 6236 | Indonesian Islamic Affairs Ministry | 33 | **Attribution required.** Government ministry text; typically usable for free Islamic education with credit — confirm for commercial packaging. |
| **ms** | 6236 | Abdullah Muhammad Basmeih | 39 | **Attribution required.** Listed on Tanzil as non-commercial unless permission. |
| **tr** | 6236 | Diyanet İşleri | 77 | **Attribution required.** Official Diyanet text; free Islamic education use is common with credit — confirm for commercial packaging. |
| **fa** | 6236 | IslamHouse.com | 135 | **Attribution required.** IslamHouse / QuranEnc ecosystem is oriented to free dawah with attribution; still follow platform terms. |
| **fr** | 6236 | Muhammad Hamidullah | 31 | **Attribution required.** Tanzil lists as non-commercial unless permission. |
| **ha** | 6236 | Abubakar Mahmoud Gumi | 32 | **Attribution required.** Tanzil lists as non-commercial unless permission. |
| **so** | 6236 | Mahmud Muhammad Abduh | 46 | **Attribution required.** Permission recommended for commercial redistribution. |
| **ps** | 6236 | Zakaria Abulsalam | 118 | **Attribution required.** Permission recommended for commercial redistribution. |
| **sw** | 6236 | Ali Muhsin Al-Barwani | 49 | **Attribution required.** Permission recommended for commercial redistribution. |

All rows: **0 missing ayahs** (verified). Text is stored unaltered from Quran.com API responses (HTML footnotes stripped only).

## Platform terms (important)

### Quran Foundation / Quran.com API
- Allowed to build apps that give beneficial Quranic experiences and **display** content to end users **unaltered**, with proper context.
- **Do not** resell / sublicense raw API dumps.
- Developer Terms include a **cache/store ≤ 1 week unless expressly permitted** clause. Bundling a permanent offline `quran.db` from the API therefore needs **express permission** from Quran Foundation for long-term commercial compliance.
- Contact: developers@quran.com / legal@quran.foundation

### Tanzil translations page
- Translations offered there are for **non-commercial** use unless permission is obtained from the translator/publisher.
- Using more than three translations: Tanzil asks for a link back to https://tanzil.net/trans/

### Arabic Uthmani text (separate from translations)
- Tanzil Quran text: **CC BY-ND 3.0** — attribution required; **do not change** the Arabic text. ✅ Allowed offline with attribution.

## Verdict for ISLAM 307

| Use case | Status |
|----------|--------|
| Free Sadaqah Jariyah offline reading **with full translator attribution** | **Intended / kept** — text unaltered; About → Data Sources lists every translator. |
| Showing Hindi when user picks Hindi (etc.) from authenticated DB | ✅ Correct — no AI conversion. |
| Play Store / commercial redistribution of translation packs | ⚠️ **Not fully cleared** until written permission from Quran Foundation and/or individual translators/publishers for the languages you ship. |
| Machine-translating from Urdu/English into other languages | ❌ Forbidden by app policy — not done. |

## What we did **not** do
- Did not invent or auto-convert any ayah translation.
- Did not remove languages from the offline DB in this pass (they remain available with attribution).
- If a language must be disabled until written permission arrives, say which ones to drop and they will be removed from picker + DB.
