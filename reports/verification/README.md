# ISLAM 307 — Source Verification Reports

Generated **2026-07-11**. Development is **blocked** until databases are rebuilt from authenticated sources.

## Reports

| File | Description |
|------|-------------|
| [VERIFICATION_SUMMARY.json](./VERIFICATION_SUMMARY.json) | Machine-readable pass/fail summary |
| [HADITH_VERIFICATION_REPORT.md](./HADITH_VERIFICATION_REPORT.md) | Full hadith audit (36,313 records) |
| [hadith_full_report.json](./hadith_full_report.json) | Per-hadith JSON (all 36,313 entries) |
| [TAFSIR_VERIFICATION_REPORT.md](./TAFSIR_VERIFICATION_REPORT.md) | Tafsir Ibn Kathir audit |
| [tafsir_full_report.json](./tafsir_full_report.json) | Per-surah coverage JSON |

## Regenerate

```bash
python tools/verification/generate_reports.py
```

## Verdict

- **hadith.db:** FAIL — unofficial source (fawazahmed0/hadith-api), not commercial-ready
- **tafsir.db:** REMOVED — the failed/incompletely licensed offline corpus is no longer bundled. Historical audit files are retained for provenance only; current Tafseer is runtime official-API-only. See `docs/TAFSEER_SOURCES_AND_LICENSES.md`.
