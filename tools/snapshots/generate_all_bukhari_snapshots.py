#!/usr/bin/env python3
"""Generate Hadith Reader HTML snapshots for every Sahih Bukhari chapter.

Layout matches the app reader:
  SAHIH BUKHARI
  <Urdu kitab title>
  Hadith X to Y
  Now reading Hadith N
  progress bar
  full authenticated Arabic

Writes under preview/snapshots/ and builds ZIP packs for local PC download.
Arabic comes only from hadith.db (no invented text).
"""

from __future__ import annotations

import gzip
import json
import os
import re
import shutil
import sqlite3
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
I18N_PATH = ROOT / "tools" / "hadith" / "chapter_i18n.json"
OUT_ROOT = ROOT / "preview" / "snapshots"
BOOK_EN = "SAHIH BUKHARI"

# Stable aliases used by existing preview links
ALIAS_SLUG = {
    2: "bukhari-iman",  # Belief — screenshot chapter
    3: "bukhari-ilm",  # Knowledge
    4: "bukhari-wudu",  # Ablutions
}

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


def slugify(num: int, title_en: str) -> str:
    if num in ALIAS_SLUG:
        return ALIAS_SLUG[num]
    s = re.sub(r"[^a-z0-9]+", "-", title_en.lower()).strip("-")[:40].strip("-")
    return f"bukhari-{num:02d}-{s}"


def esc(s: str) -> str:
    return (
        (s or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def page_html(*, kitab_ur: str, start: int, end: int, abs_n: int, local: int, total: int, arabic: str) -> str:
    progress = max(1, round((local / total) * 100))
    range_label = f"Hadith {start}" if start == end else f"Hadith {start} to {end}"
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari — {esc(kitab_ur)} — {range_label}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>{PAGE_CSS}</style>
</head>
<body>
  <article class="shot" id="shot">
    <div class="hadith-reader-heading">
      <p class="hadith-reader-book">{BOOK_EN}</p>
      <h2 class="hadith-reader-kitab" dir="rtl">{esc(kitab_ur)}</h2>
      <p class="hadith-reader-count">{range_label}</p>
      <p class="hadith-reader-now">Now reading Hadith {abs_n}</p>
      <div class="hadith-progress" aria-hidden="true" dir="ltr"><span style="width:{progress}%"></span></div>
    </div>
    <section class="hadith-reader-arabic">
      <p class="hadith-arabic" dir="rtl" lang="ar">{esc(arabic)}</p>
    </section>
  </article>
</body>
</html>
"""


def zip_dir(src: Path, zip_path: Path, arc_prefix: str | None = None) -> None:
    if zip_path.exists():
        zip_path.unlink()
    prefix = arc_prefix or src.name
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for path in sorted(src.rglob("*")):
            if path.is_dir():
                continue
            if path.suffix == ".zip":
                continue
            # Skip empty png placeholders to keep packs small for local HTML use
            if path.parent.name == "png":
                continue
            rel = path.relative_to(src)
            zf.write(path, arcname=f"{prefix}/{rel.as_posix()}")


def generate_chapter(
    *,
    slug: str,
    kitab_ur: str,
    title_en: str,
    number: int,
    start: int,
    end: int,
    rows: list,
) -> dict:
    out = OUT_ROOT / slug
    html_dir = out / "html"
    if out.exists():
        # Keep png/ if present but refresh html + index
        if html_dir.exists():
            shutil.rmtree(html_dir)
    html_dir.mkdir(parents=True, exist_ok=True)
    (out / "png").mkdir(parents=True, exist_ok=True)

    total = len(rows)
    digits = max(2, len(str(total)))
    manifest = []
    for i, row in enumerate(rows, start=1):
        abs_n = int(row["hadith_number"])
        name = f"hadith-{i:0{digits}d}"
        (html_dir / f"{name}.html").write_text(
            page_html(
                kitab_ur=kitab_ur,
                start=start,
                end=end,
                abs_n=abs_n,
                local=i,
                total=total,
                arabic=row["text_ar"] or "",
            ),
            encoding="utf-8",
        )
        manifest.append(
            {
                "local": i,
                "absolute": abs_n,
                "html": f"html/{name}.html",
                "png": f"png/{name}.png",
                "title": f"Hadith {start} to {end}",
            }
        )

    zip_name = f"{slug}-snapshots.zip"
    cards = "\n".join(
        f'<a class="card" href="{m["html"]}">'
        f'<span>Hadith {m["absolute"]}</span>'
        f'<small>{esc(kitab_ur)} · {start} to {end}</small></a>'
        for m in manifest
    )
    index = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bukhari — {esc(kitab_ur)} — Snapshots</title>
  <style>
    body {{ margin:0; font-family:Segoe UI,system-ui,sans-serif; background:#f8fafc; color:#0f172a; }}
    header {{ max-width:1100px; margin:0 auto; padding:32px 20px 12px; }}
    h1 {{ margin:0 0 8px; color:#065f46; font-size:1.6rem; }}
    p {{ color:#64748b; }}
    .grid {{ max-width:1100px; margin:0 auto; padding:12px 20px 40px; display:grid;
             grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:12px; }}
    .card {{ display:grid; gap:4px; background:#fff; border:1px solid #e2e8f0; border-radius:14px;
             padding:14px; text-decoration:none; color:inherit; }}
    .card span {{ font-weight:800; font-size:14px; color:#065f46; }}
    .card small {{ color:#64748b; font-weight:600; direction:rtl; }}
  </style>
</head>
<body>
  <header>
    <h1 dir="rtl">{esc(kitab_ur)} — Snapshots</h1>
    <p>Sahih Bukhari · Hadith {start} to {end} · {total} reader snapshots (open HTML locally).</p>
    <p>Local folder: <code>preview/snapshots/{slug}/</code></p>
    <p><a href="../{zip_name}" download
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
                "slug": slug,
                "kitab_en": title_en,
                "kitab_ur": kitab_ur,
                "chapter_number": number,
                "abs_start": start,
                "abs_end": end,
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
        f"""# Bukhari — {kitab_ur} — Snapshots

- Absolute Bukhari numbers: **{start}–{end}**
- Count: **{total}**

## Download for local PC

- ZIP: [{zip_name}](../{zip_name})
- Unzip, then open any `html/hadith-XX.html` in your browser (offline).

## Layout

Matches the Hadith reader: **SAHIH BUKHARI** · Urdu kitab · **Hadith {start} to {end}** · Now reading · Arabic text from authenticated DB.
""",
        encoding="utf-8",
    )

    zip_path = OUT_ROOT / zip_name
    zip_dir(out, zip_path, arc_prefix=slug)

    return {
        "slug": slug,
        "kitab_en": title_en,
        "kitab_ur": kitab_ur,
        "number": number,
        "start": start,
        "end": end,
        "total": total,
        "zip": zip_name,
        "index": f"{slug}/index.html",
    }


def main() -> int:
    i18n = json.loads(I18N_PATH.read_text(encoding="utf-8"))
    ur_by_en = {k: v["ur"] for k, v in i18n["chapters"]["bukhari"].items()}

    conn, tmp = open_db()
    chapters = conn.execute(
        """
        SELECT c.id, c.number, c.title,
               MIN(h.hadith_number) AS first_n,
               MAX(h.hadith_number) AS last_n,
               COUNT(*) AS cnt
        FROM chapters c
        JOIN hadiths h ON h.chapter_id = c.id
        WHERE c.book_id = 1 AND c.number > 0
        GROUP BY c.id
        ORDER BY c.number
        """
    ).fetchall()

    catalog = []
    for ch in chapters:
        rows = conn.execute(
            """
            SELECT hadith_number, text_ar
            FROM hadiths
            WHERE book_id = 1 AND chapter_id = ?
            ORDER BY hadith_number
            """,
            (ch["id"],),
        ).fetchall()
        title_en = ch["title"]
        kitab_ur = ur_by_en[title_en]
        slug = slugify(int(ch["number"]), title_en)
        start, end = int(ch["first_n"]), int(ch["last_n"])
        info = generate_chapter(
            slug=slug,
            kitab_ur=kitab_ur,
            title_en=title_en,
            number=int(ch["number"]),
            start=start,
            end=end,
            rows=rows,
        )
        catalog.append(info)
        print(
            f"OK {ch['number']:02d} {slug}: {start}-{end} ({info['total']}) -> {info['zip']}"
        )

    conn.close()
    tmp.unlink(missing_ok=True)

    # Master index
    rows_html = "\n".join(
        f'<tr>'
        f'<td>{c["number"]}</td>'
        f'<td dir="rtl">{esc(c["kitab_ur"])}</td>'
        f'<td>{c["start"]}–{c["end"]}</td>'
        f'<td>{c["total"]}</td>'
        f'<td><a href="{c["index"]}">Open</a></td>'
        f'<td><a href="{c["zip"]}" download>ZIP</a></td>'
        f"</tr>"
        for c in catalog
    )
    master = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Sahih Bukhari — All chapter snapshots</title>
  <style>
    body {{ margin:0; font-family:Segoe UI,system-ui,sans-serif; background:#f8fafc; color:#0f172a; }}
    header {{ max-width:1100px; margin:0 auto; padding:36px 20px 16px; }}
    h1 {{ margin:0 0 8px; color:#065f46; }}
    p {{ color:#64748b; line-height:1.6; }}
    .dl {{ display:inline-block;margin:8px 8px 0 0;padding:12px 16px;background:#065f46;color:#fff;
           border-radius:10px;font-weight:800;text-decoration:none; }}
    .dl.secondary {{ background:#0d9488; }}
    table {{ width:100%; max-width:1100px; margin:0 auto 40px; border-collapse:collapse; background:#fff; }}
    th, td {{ padding:10px 12px; border-bottom:1px solid #e2e8f0; text-align:left; font-size:14px; }}
    th {{ background:#ecfdf5; color:#065f46; }}
  </style>
</head>
<body>
  <header>
    <h1>Sahih Bukhari — All reader snapshots</h1>
    <p>Every chapter as static HTML matching the app reader (SAHIH BUKHARI · Urdu kitab · Hadith X to Y · Now reading · Arabic).</p>
    <p>Download a chapter ZIP, unzip on your PC, open any <code>html/hadith-XX.html</code> offline.</p>
    <p>
      <a class="dl" href="bukhari-iman-snapshots.zip" download>⬇ Kitab Iman (8–58)</a>
      <a class="dl secondary" href="bukhari-all-html-snapshots.zip" download>⬇ All chapters (HTML ZIP)</a>
    </p>
  </header>
  <table>
    <thead><tr><th>#</th><th>Kitab</th><th>Range</th><th>Count</th><th>Browse</th><th>Download</th></tr></thead>
    <tbody>
{rows_html}
    </tbody>
  </table>
</body>
</html>
"""
    (OUT_ROOT / "index.html").write_text(master, encoding="utf-8")
    (OUT_ROOT / "manifest-all.json").write_text(
        json.dumps(
            {
                "book": "bukhari",
                "chapters": catalog,
                "total_chapters": len(catalog),
                "total_hadiths": sum(c["total"] for c in catalog),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    # Mega ZIP of all chapter HTML folders (no nested zips)
    mega = OUT_ROOT / "bukhari-all-html-snapshots.zip"
    if mega.exists():
        mega.unlink()
    with zipfile.ZipFile(mega, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for c in catalog:
            folder = OUT_ROOT / c["slug"]
            for path in sorted(folder.rglob("*")):
                if not path.is_file():
                    continue
                if path.suffix == ".zip":
                    continue
                if path.parent.name == "png":
                    continue
                rel = path.relative_to(OUT_ROOT)
                zf.write(path, arcname=f"bukhari-all-html-snapshots/{rel.as_posix()}")
    print(f"Wrote master index + {mega.name} ({mega.stat().st_size // (1024*1024)} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
