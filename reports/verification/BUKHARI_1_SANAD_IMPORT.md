# Bukhari Hadith 1 — Sanad Narrator Import

Batch: `bukhari_1_ibarat_import_2026-07-12`

## Verification

- Authenticated Arabic isnad from `hadith.db` checked for all expected name fragments: **PASS**
- sunnah.com narrator IDs attached for transmitters #2–#7
- Biographical fields from provided Ibarat research file (cites Taqrib / Tahdhib / Siyar / etc.)
- Prophet ﷺ stored as `role=prophet`, order 8
- Primary companion mapping: **Umar ibn al-Khattab** (`role=primary`, order 7)

## Sanad order

| Order | Role | Arabic | English | Kunyah | Sunnah ID |
|------:|------|--------|---------|--------|----------:|
| 1 | compiler | محمد بن إسماعيل البخاري | Muhammad ibn Ismail al-Bukhari | ابو عبداللہ | — |
| 2 | in_isnad | الحميدي عبد الله بن الزبير | Abdullah ibn al-Zubayr al-Humaydi | ابو بکر | 4698 |
| 3 | in_isnad | سفيان بن عيينة | Sufyan ibn Uyaynah | ابو محمد | 3443 |
| 4 | in_isnad | يحيى بن سعيد الأنصاري | Yahya ibn Sa'id al-Ansari | ابو سعید | 8272 |
| 5 | in_isnad | محمد بن إبراهيم التيمي | Muhammad ibn Ibrahim al-Taymi | ابو عبداللہ | 6796 |
| 6 | in_isnad | علقمة بن وقاص الليثي | Alqamah ibn Waqqas al-Laythi | ابو شبل | 5719 |
| 7 | primary | عمر بن الخطاب | Umar ibn al-Khattab | ابو حفص | 5913 |
| 8 | prophet | رسول الله ﷺ | The Messenger of Allah ﷺ | ابو القاسم | — |

## Artifacts

- `app/assets/databases/narrators.db.gz`
- `preview/library/data/narrators/bukhari-1.json`
- Source file: `data/narrators/imports/bukhari_1_sanad_urdu.txt`
