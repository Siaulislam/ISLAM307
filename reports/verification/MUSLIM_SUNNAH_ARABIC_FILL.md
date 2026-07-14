# Muslim missing Arabic fill (sunnah.com)

- Generated: `2026-07-14T05:50:01.574969+00:00`
- Missing before: **203**
- Filled from sunnah.com: **4**
- Skipped: **199**
- Missing after: **199**

## Policy

- Only fill empty Muslim text_ar
- Source: sunnah.com/muslim:{n} exact Arabic copy (lettered refs like 8a accepted for URL /muslim:8)
- No AI generation
- Skip when Arabic already present under another Muslim number (duplicate guard)
- Leave empty when sunnah.com returns 404 for that number

## Filled

- `1` ← https://sunnah.com/muslim:1
- `5` ← https://sunnah.com/muslim:5
- `6` ← https://sunnah.com/muslim:6
- `7` ← https://sunnah.com/muslim:7

## Skipped reasons

- `duplicate_arabic_already_at`: **111**
- `sunnah_404`: **88**

## Notes

- Many empty USC-MSA slots already contain the same Arabic under a different local number (sunnah.com numbering variants / historical shift). Those were **not** copied again (duplicate guard).
- High numbers that 404 on `sunnah.com/muslim:{n}` cannot be filled from that authenticated URL.
