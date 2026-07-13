# Isnad Engine Gold Standard

Permanent regression oracle for Arabic sanad parsing.

- **100** verified entries per: Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasai, Ibn Majah
- Each row stores `isnad_ar` (sanad-only cut) and `expected_names` checked against Arabic Isnad
- Invariants: zero Matn leakage, no story characters, relatives not stored as names
- Gate: `python3 tools/hadith/tests/run_isnad_gold.py` (also via `run_all_isnad_gates.sh`)

Do not invent narrators. Re-build only after intentional, reviewed parser changes:
`python3 tools/hadith/isnad_engine/build_gold_standard.py`
