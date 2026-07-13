# Sanad-only narrator extraction

Narrators must come **only** from the Arabic Isnad. Matn names are never narrators.

**Result:** 5/5 checks passed.

- **PASS** — Bukhari 1 — sanad only (no matn quote)
  - `['الحميدي عبد الله بن الزبير', 'سفيان', 'يحيى بن سعيد الأنصاري', 'محمد بن إبراهيم التيمي', 'علقمة بن وقاص الليثي', 'عمر بن الخطاب']`

- **PASS** — Bukhari 2 — stop at Aisha (no الحارث)
  - `['عبد الله بن يوسف', 'مالك', 'هشام بن عروة', 'عروة', 'عائشة أم المؤمنين']`

- **PASS** — Bukhari 7 — Heraclius story (no هرقل / أبو سفيان)
  - `['أبو اليمان الحكم بن نافع', 'شعيب', 'الزهري', 'عبيد الله بن عبد الله بن عتبة بن مسعود', 'عبد الله بن عباس']`

- **PASS** — Bukhari 51 — no Heraclius matn leak
  - `['إبراهيم بن حمزة', 'إبراهيم بن سعد', 'صالح', 'ابن شهاب', 'عبيد الله بن عبد الله', 'عبد الله بن عباس']`

- **PASS** — Bukhari 1–200 matn-leak scan (0 leaks)
  - `[]`
