# Offline Tafseer license status

Last reviewed: 2026-07-14

ISLAM 307 requires permanent offline operation and potential commercial
distribution. No reviewed Tafseer provider currently grants both rights for the
requested editions.

Quran Foundation Developer Terms permit in-application API display but limit
ordinary storage to one week unless expressly permitted. That does not satisfy
the permanent offline requirement.

Therefore:

- no Tafseer text, translation, index or cache is bundled;
- no Tafseer API is called during normal use;
- AI does not retrieve or generate Tafseer;
- the UI remains a license-status placeholder;
- provider/update architecture is retained but disabled;
- a pack may be enabled only after written permission and checksum evidence are
  recorded in `LICENSES/tafsir.md` and `dataset_registry.json`.

Requested works pending permission:

- Tafsir Ibn Kathir
- Tafsir Al-Tabari
- Tafsir Al-Qurtubi
- Tafsir Al-Baghawi
- Tafsir Al-Jalalayn
- Tafsir As-Sa'di
- Tafhim-ul-Quran
- Ma'ariful Quran

Official contact for Quran Foundation:

- developers@quran.com
- legal@quran.foundation

See `LICENSE_REQUEST.md` for the required permanent-storage and commercial
redistribution request.
