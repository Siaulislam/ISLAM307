# ISLAM307 Arabic Isnad Engine

Narrators come ONLY from the Sanad (Isnad). Never from the Matn.

- Compiler is metadata of the collection — not a link in the rawi chain.
- Parallel `ح` / `ح وحدثنا` / `ثم حدثنا` / `وحدثنا` produce separate sanads (never merged).
- Relative tokens (`أبيه` / `أمه` / `جده` / `أخيه` / `عمه` / `خاله` / `مولاه`) are not stored as names; resolve from the previous narrator when recoverable. Never invent identities.
- Story characters (هرقل، كسرى، أبو جهل، …) are never narrators.
- Matn-opening verbs before رسول الله / النبي terminate the Sanad.
- Low-confidence parses go to the review queue; only approved sanads are production-ready.

## Gold Standard

`gold/` holds ≥100 Arabic-verified fixtures per Bukhari, Muslim, Abu Dawud, Tirmidhi, Nasai, Ibn Majah.

```bash
python3 tools/hadith/tests/run_isnad_gold.py
bash tools/hadith/tests/run_all_isnad_gates.sh
```

No future parser update should be merged unless all Gold Standard tests pass.
