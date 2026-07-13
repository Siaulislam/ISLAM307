# Isnad Engine — multi-collection regression

Parser must use **sanad only**. Compiler is separate. Relatives are not names.
Parallel `ح` chains stay separate. Confidence < 95% → review queue.

- **PASS** — `bukhari` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈17; parallel_split=4/5
- **PASS** — `muslim` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈113; parallel_split=36/39
- **PASS** — `abudawud` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈15; parallel_split=14/14
- **PASS** — `tirmidhi` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈7; parallel_split=5/5
- **PASS** — `nasai` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈21; parallel_split=4/4
- **PASS** — `ibnmajah` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈8; parallel_split=22/25
- **PASS** — `malik` (300 hadiths): 0 matn leaks, 0 relative-as-name; review_flagged≈38; parallel_split=0/0

## Spot checks

- **PASS** — Bukhari 1: `['الحميدي عبد الله بن الزبير', 'سفيان', 'يحيى بن سعيد الأنصاري', 'محمد بن إبراهيم التيمي', 'علقمة بن وقاص الليثي', 'عمر بن الخطاب']`
- **PASS** — Bukhari 2 relative+no الحارث: `['عبد الله بن يوسف', 'مالك', 'هشام بن عروة', 'عروة', 'عائشة أم المؤمنين']`
- **PASS** — Bukhari 7 story: `['أبو اليمان الحكم بن نافع', 'شعيب', 'الزهري', 'عبيد الله بن عبد الله بن عتبة بن مسعود', 'عبد الله بن عباس']`

**Result:** PASS (0 failure groups)

```json
{
  "bukhari": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 17,
    "parallel_ok": 4,
    "parallel_seen": 5,
    "ok": true
  },
  "muslim": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 113,
    "parallel_ok": 36,
    "parallel_seen": 39,
    "ok": true
  },
  "abudawud": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 15,
    "parallel_ok": 14,
    "parallel_seen": 14,
    "ok": true
  },
  "tirmidhi": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 7,
    "parallel_ok": 5,
    "parallel_seen": 5,
    "ok": true
  },
  "nasai": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 21,
    "parallel_ok": 4,
    "parallel_seen": 4,
    "ok": true
  },
  "ibnmajah": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 8,
    "parallel_ok": 22,
    "parallel_seen": 25,
    "ok": true
  },
  "malik": {
    "n": 300,
    "leaks": 0,
    "relative_as_name": 0,
    "review": 38,
    "parallel_ok": 0,
    "parallel_seen": 0,
    "ok": true
  }
}
```
