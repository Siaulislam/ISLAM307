#!/usr/bin/env python3
"""Generate static Hadith Reader snapshots for a Bukhari kitab chapter.

Usage:
  python3 tools/snapshots/generate_bukhari_kitab_html.py \\
    --slug bukhari-wudu \\
    --kitab-ur 'کتاب وضو کے بیان میں' \\
    --start 135 --end 247
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
BOOK_EN = "SAHIH BUKHARI"

PAGE_CSS = """
:root {
  --emerald: #0d9488;
  --emerald-deep: #065f46;
  --text: #0f172a;
  --muted: #64748b;
  --border: #e2e8f0;
  --bg: #ffffff;
}
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--text);
  font-family: "Segoe UI", system-ui, sans-serif;
}
.shot {
  width: 1080px;
  margin: 0 auto;
  padding: 36px 40px 48px;
  background: #fff;
}
.hadith-reader-heading { display: grid; gap: 4px; }
.hadith-reader-book {
  margin: 0;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--muted);
}
.hadith-reader-kitab {
  margin: 0;
  font-family: "Noto Naskh Arabic", "Noto Nastaliq Urdu", serif;
  font-size: 2rem;
  font-weight: 700;
  line-height: 1.55;
  color: var(--emerald-deep);
  text-align: right;
}
.hadith-reader-count {
  margin: 6px 0 0;
  font-size: 13px;
  font-weight: 800;
  color: var(--emerald);
}
.hadith-progress {
  margin-top: 10px;
  height: 6px;
  border-radius: 999px;
  background: #e2e8f0;
  overflow: hidden;
}
.hadith-progress > span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--emerald), #059669);
}
.hadith-reader-arabic { padding: 8px 0 4px; }
.hadith-arabic {
  margin: 0;
  padding: 8px 0 18px;
  border-bottom: 1px solid var(--border);
  font-family: "Noto Naskh Arabic", "Amiri", serif;
  font-size: 26px;
  line-height: 2.15;
  font-weight: 500;
  text-align: right;
  overflow-wrap: anywhere;
  word-break: break-word;
  color: #0f172a;
}
"""


def open_db():
    raw = gzip.decompress(HADITH_GZ.read_bytes())
    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.write(fd, raw)
    os.close(fd)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn, Path(tmp)


def page_html(kitab_ur: str, local: int, total: int, arabic: str) -> str:
    progress = max(1, round((local / total) * 100))
    ar = (
        (arabic or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari {kitab_ur} — Hadith {local} of {total}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>{PAGE_CSS}</style>
</head>
<body>
  <article class="shot" id="shot">
    <div class="hadith-reader-heading">
      <p class="hadith-reader-book">{BOOK_EN}</p>
      <h2 class="hadith-reader-kitab" dir="rtl">{kitab_ur}</h2>
      <p class="hadith-reader-count">Hadith {local} of {total}</p>
      <div class="hadith-progress" aria-hidden="true" dir="ltr"><span style="width:{progress}%"></span></div>
    </div>
    <section class="hadith-reader-arabic">
      <p class="hadith-arabic" dir="rtl" lang="ar">{ar}</p>
    </section>
  </article>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--kitab-ur", required=True)
    ap.add_argument("--start", type=int, required=True)
    ap.add_argument("--end", type=int, required=True)
    args = ap.parse_args()

    out = ROOT / "preview" / "snapshots" / args.slug
    html_dir = out / "html"
    html_dir.mkdir(parents=True, exist_ok=True)
    (out / "png").mkdir(parents=True, exist_ok=True)

    total = args.end - args.start + 1
    conn, tmp = open_db()
    rows = conn.execute(
        """
        SELECT h.hadith_number, h.text_ar
        FROM hadiths h JOIN books b ON b.id=h.book_id
        WHERE b.slug='bukhari' AND h.hadith_number BETWEEN ? AND ?
        ORDER BY h.hadith_number
        """,
        (args.start, args.end),
    ).fetchall()
    conn.close()
    tmp.unlink(missing_ok=True)
    assert len(rows) == total, f"expected {total}, got {len(rows)}"

    digits = max(2, len(str(total)))
    manifest = []
    for row in rows:
        abs_n = int(row["hadith_number"])
        local = abs_n - args.start + 1
        name = f"hadith-{local:0{digits}d}"
        (html_dir / f"{name}.html").write_text(
            page_html(args.kitab_ur, local, total, row["text_ar"] or ""),
            encoding="utf-8",
        )
        manifest.append(
            {
                "local": local,
                "absolute": abs_n,
                "html": f"html/{name}.html",
                "png": f"png/{name}.png",
                "title": f"Hadith {local} of {total}",
            }
        )
        print(f"wrote {name}.html")

    cards = "\n".join(
        f'<a class="card" href="{m["html"]}"><img src="{m["png"]}" alt="{m["title"]}" loading="lazy" />'
        f'<span>{m["title"]} <small>(Bukhari #{m["absolute"]})</small></span></a>'
        for m in manifest
    )
    zip_name = f"{args.slug}-snapshots.zip"
    index = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari — {args.kitab_ur} — Snapshots</title>
  <style>
    body {{ margin:0; font-family:Segoe UI,system-ui,sans-serif; background:#f8fafc; color:#0f172a; }}
    header {{ max-width:1100px; margin:0 auto; padding:32px 20px 12px; }}
    h1 {{ margin:0 0 8px; color:#065f46; font-size:1.6rem; }}
    p {{ color:#64748b; }}
    .grid {{ max-width:1100px; margin:0 auto; padding:12px 20px 40px; display:grid;
             grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:16px; }}
    .card {{ display:grid; gap:8px; background:#fff; border:1px solid #e2e8f0; border-radius:14px;
             padding:10px; text-decoration:none; color:inherit; }}
    .card img {{ width:100%; height:180px; object-fit:cover; object-position:top; border-radius:10px; background:#ecfdf5; }}
    .card span {{ font-weight:700; font-size:14px; }}
    .card small {{ color:#64748b; font-weight:600; }}
  </style>
</head>
<body>
  <header>
    <h1 dir="rtl">{args.kitab_ur} — Snapshots</h1>
    <p>Sahih Bukhari · {total} full hadith reader snapshots (local files + PNGs).</p>
    <p>Local folder: <code>preview/snapshots/{args.slug}/</code></p>
    <p><a href="{zip_name}" download
      style="display:inline-block;margin-top:8px;padding:10px 16px;background:#065f46;color:#fff;
      border-radius:10px;font-weight:800;text-decoration:none">⬇ Download all (ZIP)</a></p>
  </header>
  <div class="grid">{cards}</div>
</body>
</html>
"""
    (out / "index.html").write_text(index, encoding="utf-8")
    (out / "manifest.json").write_text(
        json.dumps(
            {
                "slug": args.slug,
                "kitab_ur": args.kitab_ur,
                "abs_start": args.start,
                "abs_end": args.end,
                "total": total,
                "items": manifest,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (out / "README.md").write_text(
        f"""# Bukhari — {args.kitab_ur} — Snapshots

- Absolute Bukhari numbers: **{args.start}–{args.end}**
- Local numbers: **Hadith 1–{total} of {total}**

## Download all together

- ZIP: [{zip_name}]({zip_name})
- Live: https://siaulislam.github.io/ISLAM307/preview/snapshots/{args.slug}/{zip_name}

## Local path

```
preview/snapshots/{args.slug}/
```
""",
        encoding="utf-8",
    )
    print(f"Index + manifest written under {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
