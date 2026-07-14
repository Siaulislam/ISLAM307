#!/usr/bin/env python3
"""Generate static Hadith Reader snapshots for Bukhari Kitab al-Ilm (Knowledge).

Absolute Bukhari 59–134 = local Knowledge 1–76.
Writes HTML pages matching the app reader look (full Arabic).
"""

from __future__ import annotations

import gzip
import json
import os
import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
OUT = ROOT / "preview" / "snapshots" / "bukhari-ilm"
HTML_DIR = OUT / "html"
KITAB_UR = "کتاب علم کے بیان میں"
BOOK_EN = "SAHIH BUKHARI"
ABS_START, ABS_END = 59, 134
TOTAL = ABS_END - ABS_START + 1  # 76


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
.hadith-reader-now {
  margin: 2px 0 0;
  font-size: 12px;
  font-weight: 600;
  color: var(--muted);
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


def page_html(local: int, total: int, arabic: str, *, abs_n: int) -> str:
    progress = max(1, round((local / total) * 100))
    # escape
    ar = (
        arabic.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )
    range_label = f"Hadith {ABS_START} to {ABS_END}"
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari Knowledge — {range_label}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>{PAGE_CSS}</style>
</head>
<body>
  <article class="shot" id="shot">
    <div class="hadith-reader-heading">
      <p class="hadith-reader-book">{BOOK_EN}</p>
      <h2 class="hadith-reader-kitab" dir="rtl">{KITAB_UR}</h2>
      <p class="hadith-reader-count">{range_label}</p>
      <p class="hadith-reader-now">Now reading Hadith {abs_n}</p>
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
    HTML_DIR.mkdir(parents=True, exist_ok=True)
    (OUT / "png").mkdir(parents=True, exist_ok=True)
    conn, tmp = open_db()
    rows = conn.execute(
        """
        SELECT h.hadith_number, h.text_ar
        FROM hadiths h JOIN books b ON b.id=h.book_id
        WHERE b.slug='bukhari' AND h.hadith_number BETWEEN ? AND ?
        ORDER BY h.hadith_number
        """,
        (ABS_START, ABS_END),
    ).fetchall()
    conn.close()
    tmp.unlink(missing_ok=True)

    assert len(rows) == TOTAL, f"expected {TOTAL}, got {len(rows)}"
    manifest = []
    for row in rows:
        abs_n = int(row["hadith_number"])
        local = abs_n - ABS_START + 1
        html = page_html(local, TOTAL, row["text_ar"] or "", abs_n=abs_n)
        name = f"hadith-{local:02d}"
        path = HTML_DIR / f"{name}.html"
        path.write_text(html, encoding="utf-8")
        manifest.append(
            {
                "local": local,
                "absolute": abs_n,
                "html": f"html/{name}.html",
                "png": f"png/{name}.png",
                "title": f"Hadith {ABS_START} to {ABS_END}",
            }
        )
        print(f"wrote {path.name}")

    # Index page
    cards = "\n".join(
        f'<a class="card" href="{m["html"]}"><img src="{m["png"]}" alt="{m["title"]}" loading="lazy" />'
        f'<span>{m["title"]} <small>(Bukhari #{m["absolute"]})</small></span></a>'
        for m in manifest
    )
    index = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari — کتاب علم کے بیان میں — Snapshots</title>
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
    <h1 dir="rtl">کتاب علم کے بیان میں — Snapshots</h1>
    <p>Sahih Bukhari · Knowledge · 76 full hadith reader snapshots (local files + PNGs).</p>
    <p>Local folder: <code>preview/snapshots/bukhari-ilm/</code></p>
  </header>
  <div class="grid">{cards}</div>
</body>
</html>
"""
    (OUT / "index.html").write_text(index, encoding="utf-8")
    (OUT / "manifest.json").write_text(
        json.dumps({"kitab_ur": KITAB_UR, "total": TOTAL, "items": manifest}, ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )
    print(f"Index + manifest written under {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
