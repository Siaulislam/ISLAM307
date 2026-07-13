# Sunnah.com Narrator Fill Report

Generated: `2026-07-12T12:31:58.310826+00:00`

## Policy

- Never invent narrator names.
- Fetch sunnah.com page for each missing ravi.
- Verify **same book** + **same hadith content / in-book reference** (do not trust number alone).
- If verification fails, leave empty.

## Totals

| Metric | Count |
|--------|------:|
| Attempted (were missing) | **301** |
| Imported from sunnah.com (verified) | **82** |
| Left empty (could not verify) | **211** |
| Verified page but no ravi on page | **8** |
| Fetch failed | **0** |
| Still missing after fill | **219** |

### Still missing by book

- `abudawud`: 1
- `bukhari`: 10
- `muslim`: 203
- `tirmidhi`: 5

### Import methods

- `sunnah_same_chain_previous`: 2
- `sunnah_narrated_label`: 61
- `sunnah_arabic_isnad_last_link`: 19

## Imported rows (manual check)

| Book | # | Narrator | Method | Verification |
|------|--:|----------|--------|--------------|
| Sunan Abu Dawood | 123 | Al-Miqdam b. Ma’dikarib | `sunnah_same_chain_previous` | text_and_inbook_match |
| Sunan Abu Dawood | 907 | Al-Miswar ibn Yazid al-Maliki | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Sunan Abu Dawood | 4290 | علي بن أبي طالب الهاشمي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Sahih Bukhari | 239 | Abu Huraira | `sunnah_same_chain_previous` | text_and_inbook_match |
| Sahih Bukhari | 804 | أبو هريرة الدوسي | `sunnah_arabic_isnad_last_link` | text_and_inbook_match |
| Sahih Bukhari | 5712 | Ibn `Abbas and `Aisha | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Sahih Bukhari | 5775 | Abu Huraira | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Sahih Bukhari | 6075 | `Aisha | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Sahih Bukhari | 6175 | `Abdullah bin `Umar | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Sahih Muslim | 128 | أبو هريرة الدوسي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Sahih Muslim | 209 | العباس بن عبد المطلب الهاشمي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 225 | أبو هريرة الدوسي | `sunnah_arabic_isnad_last_link` | text_and_inbook_match |
| Jami' at-Tirmidhi | 319 | أنس بن مالك الأنصاري | `sunnah_arabic_isnad_last_link` | text_and_inbook_match |
| Jami' at-Tirmidhi | 391 | عبد الله بن مالك بن بحينة | `sunnah_arabic_isnad_last_link` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 457 | جابر بن عبد الله الأنصاري | `sunnah_arabic_isnad_last_link` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 458 | يحيى بن الجزار العرني | `sunnah_arabic_isnad_last_link` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 945 | عائشة بنت أبي بكر الصديق | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1205 | النعمان بن بشير الأنصاري | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1208 | حبيب بن أبي ثابت الأسدي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1209 | أبو سعيد الخدري | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1225 | 'Abdullah bin Yazid | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1255 | Fadalah bin 'Ubaidah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1258 | 'Urwah Al-Bariqi | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1301 | Abu Hurairah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1317 | Abu Hurairah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1322 | عبد الله بن عمر العدوي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1365 | سمرة بن جندب الفزاري | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1395 | 'Abdullah bin 'Amr | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1420 | 'Abdullah bin 'Amr | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1438 | Ibn 'Umar | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1465 | 'Adi bin Hatim | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1471 | 'Adi bin Hatim | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1477 | Abu Tha'labah Al-Khushani | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1480 | Abu Waqid Al-Laithi | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1484 | Abu Sa'eed Al-Khudri | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1491 | Rafi' bin Khadij | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1492 | Rafi' bin Khadij | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1497 | Al-Bara' bin 'Azib | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1498 | 'Ali bin Abi Talib | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1500 | 'Uqbah bin 'Amir | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1515 | Salman bin 'Amir Ad-Dabbi | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1522 | Samurah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1526 | 'Aishah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1537 | Anas | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1553 | Abu Umamah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1554 | Ibn 'Umar | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1558 | 'Aishah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1560 | Abu Tha'labah Al-Khushani | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1561 | 'Ubadah bin As-Samit | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 1562 | Abu Qatadah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1565 | Qabisah bin Hulb | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1579 | Abu Hurairah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1599 | Ibn 'Abbas | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1617 | Sulaiman bin Buraidah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1618 | Anas bin Malik | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1637 | 'Abdullah bin 'Abdur-Rahman bin Abu Husain | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1705 | Ibn 'Umar | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1709 | مجاهد بن جبر القرشي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1711 | Nafi | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1756 | 'Abdullah bin Mughaffal | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1757 | Ibn 'Abbas | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1767 | Abu Sa'eed | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1770 | 'Urfajah bin As'ad | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1781 | Umm Hani | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1794 | 'Abdullah and Al-Hasan, the sons of Muhammad bin 'Ali | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1820 | Abu Hurairah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1825 | Ibn 'Abbas | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1851 | 'Umar bin Al-Khattab | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1858 | Umm Kulthum | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 1884 | Anas bin Malik | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 2129 | عائشة بنت أبي بكر الصديق | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 2392 | المقدام بن معدي كرب الكندي | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 2743 | Iyas bin Salamah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 2787 | Abu Hurairah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 2855 | 'Abdullah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 3011 | Masruq | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 3015 | Jabir bin 'Abdullah | `sunnah_narrated_label` | inbook_ref_match_empty_local_texts |
| Jami' at-Tirmidhi | 3367 | عقبة بن عامر الجهني | `sunnah_arabic_isnad_last_link` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 3717 | Abu Sa'eed Al-Khudri | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 3758 | 'Abdul-Muttalib bin Rabi'ah bin Al-Harith bin 'Abdul-Muttalib | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 3759 | Ibn 'Abbas | `sunnah_narrated_label` | inbook_ref_match_with_local_content |
| Jami' at-Tirmidhi | 3799 | 'Aishah | `sunnah_narrated_label` | inbook_ref_match_with_local_content |

## Full CSV

`reports/verification/SUNNAH_NARRATOR_FILL_REPORT.csv`
