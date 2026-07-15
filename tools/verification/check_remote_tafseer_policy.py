#!/usr/bin/env python3
"""Fail when production code regresses to bundled/local Tafseer content."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FORBIDDEN_FILES = [
    ROOT / "app" / "assets" / "databases" / "tafsir.db.gz",
    ROOT / "app" / "assets" / "modules" / "tafsir_sources.json",
    ROOT / "preview" / "library" / "data" / "tafsir" / "ibn-kathir.json.gz",
    ROOT / "preview" / "library" / "data" / "tafsir" / "sources.json",
]

FORBIDDEN_CODE = {
    ROOT / "app" / "lib": ["tafsir.db", "tafsir_sources.json"],
    ROOT / "preview" / "library" / "library.js": ["data/tafsir/"],
    ROOT / "tools" / "design" / "export_preview_library.py": ["export_tafsir"],
}

ALLOWED_CLEANUP_FILES = {
    ROOT / "app" / "lib" / "core" / "tafsir" / "legacy_tafsir_cleanup_io.dart",
}


def main() -> int:
    errors: list[str] = []
    for path in FORBIDDEN_FILES:
        if path.exists():
            errors.append(f"Bundled Tafseer file exists: {path.relative_to(ROOT)}")

    for path, needles in FORBIDDEN_CODE.items():
        files = path.rglob("*") if path.is_dir() else [path]
        for file in files:
            if not file.is_file() or file.suffix not in {".dart", ".js", ".py"}:
                continue
            if file in ALLOWED_CLEANUP_FILES:
                continue
            text = file.read_text(encoding="utf-8", errors="replace")
            for needle in needles:
                if needle in text:
                    errors.append(
                        f"Forbidden local Tafseer dependency {needle!r} in "
                        f"{file.relative_to(ROOT)}"
                    )

    if errors:
        raise SystemExit("\n".join(errors))
    print("Remote Tafseer policy check passed: no bundled Tafseer content.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
