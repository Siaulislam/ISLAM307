#!/usr/bin/env python3
"""Release gate for bundled religious datasets and license evidence."""

from __future__ import annotations

import json
import gzip
import hashlib
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "app" / "assets" / "modules" / "dataset_registry.json"
FEATURES = ROOT / "app" / "assets" / "modules" / "feature_modules.json"

ALLOWED_BUNDLED = {
    "app/assets/databases/quran.db": "quran-arabic-tanzil",
}

ALLOWED_PREVIEW_DATA = {
    "preview/library/data/hadith/books.json",
    "preview/library/data/manifest.json",
    "preview/library/data/quran/ayahs.json.gz",
    "preview/library/data/quran/surahs.json",
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
    feature_payload = json.loads(FEATURES.read_text(encoding="utf-8"))
    features = {row["id"]: row for row in feature_payload["features"]}
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
    preview_files = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "preview/library/data").rglob("*")
        if path.is_file()
    }
    unexpected_preview = preview_files - ALLOWED_PREVIEW_DATA
    if unexpected_preview:
        errors.append(
            f"Unexpected preview content packs: {sorted(unexpected_preview)}"
        )

    for dataset_id, record in records.items():
        evidence = ROOT / record["evidence"]
        if not evidence.exists():
            errors.append(f"{dataset_id} license evidence missing: {record['evidence']}")
        if record["status"] in {"approved_for_bundling", "app_owned"}:
            for key in ("original_source", "license", "version", "attribution"):
                if not str(record.get(key) or "").strip():
                    errors.append(f"{dataset_id} missing approved metadata: {key}")
    branding = records.get("app-owned-branding")
    if branding is None or branding.get("status") != "app_owned":
        errors.append("Packaged branding assets lack an app-owned license record")
    for feature_id, feature in features.items():
        if feature["dataset_id"] not in records:
            errors.append(
                f"Feature {feature_id} references unknown dataset "
                f"{feature['dataset_id']}"
            )
    for dataset_id, record in records.items():
        for feature_id in record.get("feature_ids", []):
            feature = features.get(feature_id)
            if feature is None:
                errors.append(
                    f"Dataset {dataset_id} references missing feature {feature_id}"
                )
            elif feature["dataset_id"] != dataset_id:
                errors.append(
                    f"Feature {feature_id} does not map back to {dataset_id}"
                )

    quran_db = sqlite3.connect(ROOT / "app/assets/databases/quran.db")
    quran_meta = dict(quran_db.execute("SELECT key,value FROM meta"))
    digest = hashlib.sha256()
    for surah, ayah, text in quran_db.execute(
        """
        SELECT surah_number, ayah_number, text_uthmani
        FROM ayahs ORDER BY global_number
        """
    ):
        digest.update(f"{surah}:{ayah}\t{text}\n".encode("utf-8"))
    actual_checksum = digest.hexdigest()
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
    structure_count = quran_db.execute(
        """
        SELECT
          (SELECT COUNT(*) FROM pages_madani) +
          (SELECT COUNT(*) FROM pages_13_line) +
          (SELECT COUNT(*) FROM juz) +
          (SELECT COUNT(*) FROM ruku) +
          (SELECT COUNT(*) FROM sajdah)
        """
    ).fetchone()[0]
    structured_ayahs = quran_db.execute(
        """
        SELECT COUNT(*) FROM ayahs
        WHERE text_tajweed IS NOT NULL OR page_madani IS NOT NULL
           OR page_13_line IS NOT NULL OR juz IS NOT NULL
           OR hizb IS NOT NULL OR rub_el_hizb IS NOT NULL
           OR ruku IS NOT NULL OR manzil IS NOT NULL
           OR sajda_number IS NOT NULL OR has_sajda != 0
           OR has_rub_el_hizb != 0
        """
    ).fetchone()[0]
    quran_db.close()
    if quran_meta.get("schema_version") != "6_tanzil_arabic_only":
        errors.append("quran.db is not the sanitized Arabic-only schema")
    expected_checksum = records["quran-arabic-tanzil"].get("checksum_sha256")
    if (
        quran_meta.get("text_sha256") != expected_checksum
        or actual_checksum != expected_checksum
    ):
        errors.append("quran.db Arabic text checksum does not match registry")
    if translated:
        errors.append(f"quran.db contains {translated} permission-pending translations")
    if word_count:
        errors.append(f"quran.db contains {word_count} permission-pending word rows")
    if structure_count or structured_ayahs:
        errors.append(
            "quran.db contains permission-pending structural/Tajweed metadata"
        )

    preview_path = ROOT / "preview/library/data/quran/ayahs.json.gz"
    preview = json.loads(gzip.decompress(preview_path.read_bytes()))
    preview_digest = hashlib.sha256()
    forbidden_translation_keys = {
        "en", "ur", "hi", "fil", "bn", "idn", "ms", "tr", "fa", "fr",
        "ha", "so", "ps", "sw",
    }
    preview_ayahs = preview.get("ayahs", [])
    if len(preview_ayahs) != 6236:
        errors.append("Quran preview does not contain exactly 6236 ayahs")
    allowed_ayah_keys = {"s", "a", "ar", "p", "j", "ruku"}
    for ayah in preview_ayahs:
        if set(ayah) - allowed_ayah_keys:
            errors.append(
                f"Quran preview contains unexpected fields: "
                f"{sorted(set(ayah) - allowed_ayah_keys)}"
            )
            break
        if forbidden_translation_keys.intersection(ayah):
            errors.append("Quran preview contains permission-pending translation fields")
            break
        if any(ayah.get(key) is not None for key in ("p", "j", "ruku")):
            errors.append("Quran preview contains permission-pending structure metadata")
            break
        preview_digest.update(
            f"{ayah['s']}:{ayah['a']}\t{ayah['ar']}\n".encode("utf-8")
        )
    if preview_digest.hexdigest() != expected_checksum:
        errors.append("Quran preview Arabic checksum does not match registry")

    books = json.loads(
        (ROOT / "preview/library/data/hadith/books.json").read_text(
            encoding="utf-8"
        )
    )
    if books.get("books") != [] or books.get("count") != 0:
        errors.append("Hadith preview placeholder contains bundled records")
    manifest = json.loads(
        (ROOT / "preview/library/data/manifest.json").read_text(
            encoding="utf-8"
        )
    )
    if manifest.get("quran", {}).get("translations") != []:
        errors.append("Preview manifest claims permission-pending translations")
    for key in ("hadith", "tafsir", "narrators"):
        if manifest.get(key, {}).get("status") != "permission_pending":
            errors.append(f"Preview manifest does not gate {key}")
    surahs = json.loads(
        (ROOT / "preview/library/data/quran/surahs.json").read_text(
            encoding="utf-8"
        )
    )
    if len(surahs.get("surahs", [])) != 114:
        errors.append("Quran preview Surah catalog must contain 114 rows")

    if errors:
        raise SystemExit("\n".join(errors))
    print(
        "Dataset license gate passed: only explicitly approved content is bundled."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
