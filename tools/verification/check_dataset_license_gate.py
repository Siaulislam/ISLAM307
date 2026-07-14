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

ALLOWED_MODULES = {
    "app/assets/modules/data_sources.json",
    "app/assets/modules/dataset_registry.json",
    "app/assets/modules/feature_modules.json",
}

ALLOWED_PREVIEW_SHELL = {
    "preview/icons.html",
    "preview/index.html",
    "preview/licenses.html",
    "preview/library/index.html",
    "preview/library/library.css",
    "preview/library/library.js",
}

ALLOWED_FLUTTER_ASSETS = {
    "assets/databases/quran.db",
    "assets/branding/",
    "assets/branding/hadith/",
    "assets/branding/books/",
    "assets/branding/books/covers/",
    "assets/modules/",
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
    module_files = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "app/assets/modules").rglob("*")
        if path.is_file()
    }
    if module_files != ALLOWED_MODULES:
        errors.append(
            f"Unexpected packaged module assets: "
            f"{sorted(module_files - ALLOWED_MODULES)}"
        )
    preview_shell = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / "preview").rglob("*")
        if path.is_file()
        and "preview/library/data/" not in path.relative_to(ROOT).as_posix()
        and "preview/branding/" not in path.relative_to(ROOT).as_posix()
    }
    if preview_shell != ALLOWED_PREVIEW_SHELL:
        errors.append(
            f"Unexpected preview shell files: "
            f"{sorted(preview_shell - ALLOWED_PREVIEW_SHELL)}"
        )
    automatic_network_markers = (
        'fonts.googleapis.com',
        'fonts.gstatic.com',
        '<script src="http',
        '<link href="http',
        "fetch('http",
        'fetch("http',
    )
    for relative in ALLOWED_PREVIEW_SHELL:
        text = (ROOT / relative).read_text(encoding="utf-8", errors="replace")
        for marker in automatic_network_markers:
            if marker in text:
                errors.append(
                    f"Preview performs an automatic network request: "
                    f"{relative} ({marker})"
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
    else:
        if tree_checksum(
            ROOT / "app/assets/branding"
        ) != branding.get("checksum_sha256"):
            errors.append("App branding checksum does not match license record")
        if tree_checksum(
            ROOT / "preview/branding"
        ) != branding.get("preview_checksum_sha256"):
            errors.append("Preview branding checksum does not match license record")
    fonts = records.get("noto-fonts")
    if fonts is None or fonts.get("status") != "approved_for_bundling":
        errors.append("Bundled fonts lack an approved license record")
    elif tree_checksum(
        ROOT / "app/assets/fonts"
    ) != fonts.get("checksum_sha256"):
        errors.append("Bundled font checksum does not match license record")

    pubspec_lines = (
        ROOT / "app/pubspec.yaml"
    ).read_text(encoding="utf-8").splitlines()
    in_assets = False
    declared_assets: set[str] = set()
    for line in pubspec_lines:
        if line.strip() == "assets:":
            in_assets = True
            continue
        if in_assets and line.strip() == "fonts:":
            break
        if in_assets and line.strip().startswith("- "):
            declared_assets.add(line.strip()[2:])
    if declared_assets != ALLOWED_FLUTTER_ASSETS:
        errors.append(
            f"Unexpected Flutter asset declarations: "
            f"{sorted(declared_assets - ALLOWED_FLUTTER_ASSETS)}"
        )
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
    ayah_counts: dict[int, int] = {}
    for surah, ayah, text in quran_db.execute(
        """
        SELECT surah_number, ayah_number, text_uthmani
        FROM ayahs ORDER BY global_number
        """
    ):
        digest.update(f"{surah}:{ayah}\t{text}\n".encode("utf-8"))
        ayah_counts[surah] = ayah_counts.get(surah, 0) + 1
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
    surah_rows = quran_db.execute(
        """
        SELECT number, name_ar, name_en, name_transliteration,
               revelation_place, ayah_count, bismillah_pre
        FROM surahs ORDER BY number
        """
    ).fetchall()
    foreign_key_errors = list(quran_db.execute("PRAGMA foreign_key_check"))
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
    if foreign_key_errors:
        errors.append(f"quran.db foreign key errors: {foreign_key_errors[:3]}")
    if len(surah_rows) != 114:
        errors.append("quran.db Surah catalog must contain 114 generated rows")
    if [row[0] for row in surah_rows] != list(range(1, 115)):
        errors.append("quran.db Surah numbers are not exactly 1–114")
    for number, name_ar, name_en, transliteration, place, count, bismillah in surah_rows:
        if (
            name_ar != f"سورة {number}"
            or name_en != f"Surah {number}"
            or transliteration is not None
            or place is not None
            or bismillah != 0
            or not isinstance(count, int)
            or count <= 0
            or count != ayah_counts.get(number)
        ):
            errors.append("quran.db contains unverified Surah metadata")
            break

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
    preview_surahs = surahs.get("surahs", [])
    if len(preview_surahs) != 114:
        errors.append("Quran preview Surah catalog must contain 114 rows")
    if [row.get("n") for row in preview_surahs] != list(range(1, 115)):
        errors.append("Quran preview Surah numbers are not exactly 1–114")
    for row in preview_surahs:
        number = row.get("n")
        if (
            set(row) != {"n", "en", "ar", "ayahs"}
            or row.get("en") != f"Surah {number}"
            or row.get("ar") != f"سورة {number}"
            or row.get("ayahs") != ayah_counts.get(number)
        ):
            errors.append("Quran preview contains unverified Surah metadata")
            break

    if errors:
        raise SystemExit("\n".join(errors))
    print(
        "Dataset license gate passed: only explicitly approved content is bundled."
    )
    return 0


def tree_checksum(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


if __name__ == "__main__":
    raise SystemExit(main())
