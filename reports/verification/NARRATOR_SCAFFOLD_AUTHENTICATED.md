# Narrator Authenticated Scaffold Report

Batch: `authenticated_attribution_scaffold_2026-07-12`

## Policy

- Never invent narrator biographies with AI.
- Scaffold identity strings ONLY from authenticated hadith packs (`narrator` field + Arabic `ravi_chain`).
- Classical fields (kunyah, nasab, birth/death, jarḥ wa taʿdīl, teachers, students, books) stay **empty** until a Bukhari-1-style licensed/research import is provided.
- Wikipedia / blogs / unverified sites / non-Sunni sources are forbidden.

## Results

| Metric | Count |
|--------|------:|
| Unique authenticated identity strings | 26510 |
| Narrator rows created this run | 26502 |
| Existing narrators reused (incl. Bukhari 1) | 8 |
| Narrator rows total | 26510 |
| Hadith↔narrator relations inserted | 157162 |
| Relations total | 157170 |
| Rows with any classical bio field | 8 |

## Books covered

Bukhari, Muslim, Abu Dawud, Tirmidhi — every authenticated primary attribution and isnad-chain name now has a Narrator Detail page shell using the standard راوی معلومات table.

## Next imports (required for full classical profiles)

Provide research/licensed extracts (same procedure as `data/narrators/imports/bukhari_1_sanad_urdu.txt`) citing:

Tahdhib al-Kamal, Tahdhib al-Tahdhib, Taqrib al-Tahdhib, Al-Jarh wa al-Ta'dil, Siyar A'lam al-Nubala', Tarikh al-Kabir, Al-Isabah, Al-Isti'ab, Usd al-Ghabah, Fath al-Bari.

Until then, Detail pages show Narrator ID + authenticated name attribution only; other fields remain blank by design.
