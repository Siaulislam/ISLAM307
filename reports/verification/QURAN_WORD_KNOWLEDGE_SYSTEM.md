# Quran Word-by-Word Knowledge System

**Policy:** Sadaqah Jariyah · no ads · no paid unlocks · no AI-generated Quran content.

## Offline data (`quran.db`)

| Table | Rows | Source |
|-------|-----:|--------|
| `quran_words` | 77,429 | Quranic Arabic Corpus morphology v0.4 + Quran.com EN/UR glosses |
| `quran_word_parts` | 128,219 | QAC segments (prefix / stem / suffix) |
| `quran_words_fts` | 77,429 | Offline FTS search |

## UX

1. Tap Arabic word → instant **Word Meaning** popup (Arabic · Urdu · English · root)
2. Tap **More · Full Word Analysis** → full authenticated fields
3. Tap **Open Root** → root page (attested glosses + derived forms + ayahs)

Missing fields show: **No authentic reference found.**

## AI

Assistant searches local DB only. Word “AI Explanation” concatenates authenticated fields — never invents meanings.

## Preview packs

`preview/library/data/quran/words/{1..114}.json.gz` — 77,429 words.
