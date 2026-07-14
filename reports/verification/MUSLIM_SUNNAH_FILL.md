# Sahih Muslim — sunnah.com data fill

Same process as MOQDEMA/Introduction: subjects + Arabic/English from **sunnah.com** (Wayback mirrors), Urdu from authentic **urd-muslim** edition only. **No AI-generated hadith text.**

## Before → After

| Field | Before missing | After missing | Filled |
|------|---------------:|--------------:|-------:|
| Arabic | 203 | 37 | 166 |
| English | 203 | 36 | 167 |
| Urdu | 105 | 105 | 0 |

## Subjects
- All **57/57** kitab subjects now have Arabic titles from sunnah.com (e.g. Introduction / المقدمة, The Book of Faith / كتاب الإيمان)
- **7150** hadiths stamped with bab (chapter) English + Arabic titles from sunnah.com

## Remaining gaps (not invented)
- **Arabic (37)**: placeholder rows with no Arabic/English body on sunnah.com or in ara/eng editions. Many still have Urdu chain notes only.
- **Urdu (105)**: empty in authentic `urd-muslim` (including Introduction 56–92). Not machine-translated.

Missing AR: `[1, 128, 209, 248, 794, 881, 1251, 1332, 1648, 1778, 2295, 2381, 2810, 3262, 3463, 3525, 3836, 5384, 5393, 5637, 6144, 6527, 6528, 6529, 6792, 7020, 7144, 7325, 7371, 7513, 7514, 7515, 7516, 7517, 7518, 7519, 7557]`

Missing UR: `[56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 2940, 2941, 2942, 2943, 2944, 2945, 2946, 4678, 5196, 5197, 5198, 5199, 5200, 5201, 5202, 5203, 5204, 5205, 5206, 5207, 5208, 5209, 5210, 5541, 5542, 5543, 5544, 5545, 5996, 5997, 5998, 5999, 6000, 6001, 6002, 6003, 7016, 7020, 7331, 7332, 7333, 7334, 7335, 7336, 7337, 7338, 7339, 7340, 7341, 7342, 7343, 7447, 7448, 7449, 7450, 7451, 7452, 7453, 7454, 7455, 7456, 7457, 7458, 7459, 7460, 7461, 7462, 7463]`

## Tool
`python3 tools/hadith/fill_muslim_from_sunnah.py`
