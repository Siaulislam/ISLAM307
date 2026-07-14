#!/usr/bin/env python3
"""Release gate for bundled religious datasets and license evidence."""

from __future__ import annotations

import json
import gzip
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "app" / "assets" / "modules" / "dataset_registry.json"

ALLOWED_BUNDLED = {
    "app/assets/databases/quran.db": "quran-arabic-tanzil",
}

FORBIDDEN_PATHS = [
    "app/assets/databases/hadith.db",
    "app/assets/databases/hadith.db.gz",
    "app/assets/databases/narrators.db.gz",
    "app/assets/databases/tafsir.db.gz",
    "preview/library/data/tafsir/ibn-kathir.json.gz",
    "preview/library/data/hadith/bukhari.json.gz",
    "preview/library/data/hadith/muslim.json.gz",
    "preview/library/data/hadith/abudawud.json.gz",
    "preview/library/data/hadith/tirmidhi.json.gz",
]


def main() -> int:
    payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    records = {row["id"]: row for row in payload["datasets"]}
    errors: list[str] = []

    for path, dataset_id in ALLOWED_BUNDLED.items():
        file = ROOT / path
        record = records.get(dataset_id)
        if not file.exists():
            errors.append(f"Approved asset missing: {path}")
            continue
        if not record:
            errors.append(f"No registry record for {path}")
            continue
        if record["status"] != "approved_for_bundling":
            errors.append(f"{path} is not approved_for_bundling")
        if not record["offline_redistribution"]:
            errors.append(f"{path} lacks offline redistribution permission")
        if not record["commercial_distribution"]:
            errors.append(f"{path} lacks commercial distribution permission")

    for path in FORBIDDEN_PATHS:
        if (ROOT / path).exists():
            errors.append(f"Permission-pending content is bundled: {path}")
    unexpected_databases = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "app/assets/databases").glob("*")
        if path.is_file()
    } - set(ALLOWED_BUNDLED)
    if unexpected_databases:
        errors.append(
            f"Unregistered bundled databases: {sorted(unexpected_databases)}"
        )
    snapshot_files = [
        path
        for path in (ROOT / "preview/snapshots").rglob("*")
        if path.is_file()
    ] if (ROOT / "preview/snapshots").exists() else []
    if snapshot_files:
        errors.append("Generated religious-content snapshots are bundled")

    for dataset_id, record in records.items():
        evidence = ROOT / record["evidence"]
        if not evidence.exists():
            errors.append(f"{dataset_id} license evidence missing: {record['evidence']}")
        if record["status"] in {"approved_for_bundling", "app_owned"}:
            for key in ("original_source", "license", "version", "attribution"):
                if not str(record.get(key) or "").strip():
                    errors.append(f"{dataset_id} missing approved metadata: {key}")

    quran_db = sqlite3.connect(ROOT / "app/assets/databases/quran.db")
    quran_meta = dict(quran_db.execute("SELECT key,value FROM meta"))
    translated = quran_db.execute(
        """
        SELECT COUNT(*) FROM ayahs
        WHERE translation_en IS NOT NULL OR translation_ur IS NOT NULL
           OR translation_hi IS NOT NULL OR translation_fil IS NOT NULL
           OR translation_bn IS NOT NULL OR translation_id IS NOT NULL
           OR translation_ms IS NOT NULL OR translation_tr IS NOT NULL
           OR translation_fa IS NOT NULL OR translation_fr IS NOT NULL
           OR translation_ha IS NOT NULL OR translation_so IS NOT NULL
           OR translation_ps IS NOT NULL OR translation_sw IS NOT NULL
        """
    ).fetchone()[0]
    word_count = quran_db.execute("SELECT COUNT(*) FROM quran_words").fetchone()[0]
    quran_db.close()
    if quran_meta.get("schema_version") != "6_tanzil_arabic_only":
        errors.append("quran.db is not the sanitized Arabic-only schema")
    if translated:
        errors.append(f"quran.db contains {translated} permission-pending translations")
    if word_count:
        errors.append(f"quran.db contains {word_count} permission-pending word rows")

    preview_path = ROOT / "preview/library/data/quran/ayahs.json.gz"
    preview = json.loads(gzip.decompress(preview_path.read_bytes()))
    forbidden_translation_keys = {
        "en", "ur", "hi", "fil", "bn", "idn", "ms", "tr", "fa", "fr",
        "ha", "so", "ps", "sw",
    }
    for ayah in preview.get("ayahs", []):
        if forbidden_translation_keys.intersection(ayah):
            errors.append("Quran preview contains permission-pending translation fields")
            break

    if errors:
        raise SystemExit("\n".join(errors))
    print(
        "Dataset license gate passed: only explicitly approved content is bundled."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
