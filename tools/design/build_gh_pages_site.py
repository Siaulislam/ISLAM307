#!/usr/bin/env python3
"""Build static site for GitHub Pages (same idea as XMONEY on github.io)."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "_site"

COPY_DIRS = [
    ("preview", "preview"),
    ("design/mockups", "design/mockups"),
    ("app/assets/branding", "app/assets/branding"),
    ("reports/verification", "reports/verification"),
]

INDEX_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ISLAM 307</title>
  <meta http-equiv="refresh" content="0; url=preview/index.html" />
  <style>
    body { font-family: Segoe UI, system-ui, sans-serif; display:flex; align-items:center; justify-content:center; min-height:100vh; background:#ecfdf5; color:#065f46; }
    a { color:#0F8B5F; font-weight:700; }
  </style>
</head>
<body>
  <p>Loading ISLAM 307… <a href="preview/index.html">Open preview</a></p>
</body>
</html>
"""


def patch_preview_index(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    text = text.replace('href="/design/', 'href="../design/')
    text = text.replace('href="/preview/', 'href="')
    text = text.replace('href="/reports/', 'href="../reports/')
    text = text.replace("Local Preview", "Live Preview")
    text = text.replace(
        "Same style as XMONEY local preview: run <code>scripts/start-local-preview.ps1</code> then open these links in Chrome.",
        "Same style as <strong>XMONEY</strong> on GitHub Pages — open mockups and icons in Chrome.",
    )
    path.write_text(text, encoding="utf-8")


def patch_icons_html(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    text = text.replace('src="/app/assets/', 'src="../app/assets/')
    path.write_text(text, encoding="utf-8")


def main() -> int:
    # Ensure web library packs exist for Pages (Quran/Hadith/Tafsir).
    export_script = ROOT / "tools" / "design" / "export_preview_library.py"
    library_manifest = ROOT / "preview" / "library" / "data" / "manifest.json"
    if export_script.exists() and not library_manifest.exists():
        import subprocess

        subprocess.check_call([sys.executable, str(export_script)], cwd=ROOT)

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    for src, dest in COPY_DIRS:
        src_path = ROOT / src
        dest_path = OUT / dest
        if src_path.is_dir():
            shutil.copytree(src_path, dest_path)

    (OUT / "index.html").write_text(INDEX_HTML, encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")

    patch_preview_index(OUT / "preview" / "index.html")
    patch_icons_html(OUT / "preview" / "icons.html")

    print(f"Built GitHub Pages site -> {OUT}")
    print("Deploy URL: https://siaulislam.github.io/ISLAM307/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
