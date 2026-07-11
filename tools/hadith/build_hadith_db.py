#!/usr/bin/env python3
"""Build ISLAM 307 hadith.db from authenticated sources only (Sunnah.com primary)."""

from __future__ import annotations

import argparse
import gzip
import json
import os
import re
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("hadith_books.json")
SCHEMA = Path(__file__).with_name("schema.sql")
CONFIG_EXAMPLE = Path(__file__).with_name("sunnah_config.example.json")
CONFIG_LOCAL = Path(__file__).with_name("sunnah_config.local.json")
CACHE = ROOT / "tools" / "hadith" / "cache" / "sunnah"
DEFAULT_OUT = ROOT / "app" / "assets" / "databases" / "hadith.db"

GRADE_NOT_VERIFIED = "Grade not verified."


def load_config() -> dict:
    path = CONFIG_LOCAL if CONFIG_LOCAL.exists() else CONFIG_EXAMPLE
    cfg = json.loads(path.read_text(encoding="utf-8"))
    env_key = os.environ.get("SUNNAH_API_KEY", "").strip()
    if env_key:
        cfg["api_key"] = env_key
    key = (cfg.get("api_key") or "").strip()
    if not key or key == "YOUR_SUNNAH_COM_API_KEY":
        raise SystemExit(
            "Missing Sunnah.com API key.\n"
            "1. Request a key: https://sunnah.com/developers\n"
            "2. Copy tools/hadith/sunnah_config.example.json → sunnah_config.local.json\n"
            "   OR set environment variable SUNNAH_API_KEY"
        )
    return cfg


def cache_path(name: str) -> Path:
    safe = re.sub(r"[^\w\-.]", "_", name)
    return CACHE / f"{safe}.json"


def fetch_api(cfg: dict, path: str) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    cpath = cache_path(path)
    if cpath.exists():
        return json.loads(cpath.read_text(encoding="utf-8"))

    url = cfg["api_base"].rstrip("/") + path
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "ISLAM307-hadith-builder/2.0",
            "X-API-KEY": cfg["api_key"],
        },
    )
    delay = float(cfg.get("request_delay_seconds", 0.35))
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            cpath.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            time.sleep(delay)
            return data
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {e.code} for {url}: {body}") from e
        except Exception:
            if attempt == 4:
                raise
            time.sleep(1.5)
    raise RuntimeError(url)


def paginate(cfg: dict, path: str) -> list[dict]:
    limit = int(cfg.get("page_limit", 100))
    page = 1
    items: list[dict] = []
    while True:
        sep = "&" if "?" in path else "?"
        payload = fetch_api(cfg, f"{path}{sep}limit={limit}&page={page}")
        batch = payload.get("data") or []
        items.extend(batch)
        nxt = payload.get("next")
        if not nxt or not batch:
            break
        page = int(nxt)
    return items


def lang_block(blocks: list[dict], lang: str) -> dict:
    for b in blocks or []:
        if b.get("lang") == lang:
            return b
    return {}


def extract_narrator(text_en: str) -> str | None:
    if not text_en:
        return None
    m = re.match(r"^Narrated\s+([^:]+):", text_en.strip(), re.IGNORECASE)
    return m.group(1).strip() if m else None


def insert_grades(conn: sqlite3.Connection, hadith_id: int, grades_en: list, grades_ar: list) -> str:
    rows: list[tuple] = []
    order = 0
    for lang, grades in (("en", grades_en), ("ar", grades_ar)):
        for g in grades or []:
            grade = (g.get("grade") or "").strip()
            scholar = (g.get("graded_by") or "").strip() or None
            if not grade:
                continue
            rows.append((hadith_id, grade, scholar, lang, order))
            order += 1
    if rows:
        conn.executemany(
            "INSERT INTO hadith_grades(hadith_id, grade, graded_by, language, sort_order) VALUES (?,?,?,?,?)",
            rows,
        )
    parts = []
    for _, grade, scholar, lang, _ in rows:
        label = f"{grade} ({scholar})" if scholar else grade
        parts.append(label)
    return "; ".join(parts) if parts else GRADE_NOT_VERIFIED


def build(output: Path, sample_limit: int | None = None) -> None:
    cfg = load_config()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    url_tpl = manifest["reference_url_template"]

    if output.exists():
        output.unlink()
    output.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(output)
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("builder", "ISLAM307 hadith builder v2"))
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("primary_source", manifest["primary_provider"]))
    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("grade_unknown_label", GRADE_NOT_VERIFIED))

    for src in manifest["allowed_sources"]:
        conn.execute(
            "INSERT INTO source_providers(slug, name, website) VALUES (?,?,?)",
            (src["slug"], src["name"], src["website"]),
        )

    total_hadiths = 0

    for order, book in enumerate(manifest["books"], start=1):
        collection = book["collection"]
        slug = book["slug"]
        print(f"Processing {book['name_en']} ({collection})...")

        conn.execute(
            """INSERT INTO books(id, slug, name_en, name_ar, sort_order, source_provider, source_collection)
               VALUES (?,?,?,?,?,?,?)""",
            (order, slug, book["name_en"], book["name_ar"], order, manifest["primary_provider"], collection),
        )
        book_id = order

        kitab_books = paginate(cfg, f"/v1/collections/{collection}/books")
        chapter_key_map: dict[tuple[str, str], int] = {}
        chapter_count = 0

        if not kitab_books:
            coll = fetch_api(cfg, f"/v1/collections/{collection}")
            total = int(coll.get("totalAvailableHadith") or coll.get("totalHadith") or 0)
            kitab_books = [{"bookNumber": "1", "book": [{"lang": "en", "name": book["name_en"]}, {"lang": "ar", "name": book["name_ar"]}]}]
            if total <= 0:
                print(f"  Warning: no books/hadith count for {collection}")
                continue

        for kb in kitab_books:
            kitab_number = str(kb.get("bookNumber", ""))
            kitab_en = lang_block(kb.get("book") or [], "en").get("name") or ""
            kitab_ar = lang_block(kb.get("book") or [], "ar").get("name") or ""

            chapters = paginate(cfg, f"/v1/collections/{collection}/books/{urllib.parse.quote(kitab_number)}/chapters")
            for ch in chapters:
                ch_en = lang_block(ch.get("chapter") or [], "en")
                ch_ar = lang_block(ch.get("chapter") or [], "ar")
                bab_id = str(ch.get("chapterId", ch_en.get("chapterNumber", "")))
                title_en = (ch_en.get("chapterTitle") or bab_id).strip()
                title_ar = (ch_ar.get("chapterTitle") or "").strip() or None
                conn.execute(
                    """INSERT INTO chapters(
                        book_id, kitab_number, kitab_title_en, kitab_title_ar,
                        number, title_en, title_ar
                    ) VALUES (?,?,?,?,?,?,?)""",
                    (book_id, kitab_number, kitab_en or None, kitab_ar or None, int(float(bab_id)), title_en, title_ar),
                )
                cid = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
                chapter_key_map[(kitab_number, bab_id)] = cid
                chapter_count += 1

            hadiths = paginate(
                cfg,
                f"/v1/collections/{collection}/books/{urllib.parse.quote(kitab_number)}/hadiths",
            )
            if not hadiths and len(kitab_books) == 1:
                coll = fetch_api(cfg, f"/v1/collections/{collection}")
                total = int(coll.get("totalAvailableHadith") or coll.get("totalHadith") or 0)
                cap = min(total, sample_limit - total_hadiths) if sample_limit else total
                for hn in range(1, cap + 1):
                    try:
                        hadiths.append(fetch_api(cfg, f"/v1/collections/{collection}/hadiths/{hn}"))
                    except RuntimeError:
                        continue
            for h in hadiths:
                if sample_limit is not None and total_hadiths >= sample_limit:
                    break
                hn = int(h.get("hadithNumber"))
                ref_url = url_tpl.format(collection=collection, hadith_number=hn)
                en = lang_block(h.get("hadith") or [], "en")
                ar = lang_block(h.get("hadith") or [], "ar")
                text_en = (en.get("body") or "").strip() or None
                text_ar = (ar.get("body") or "").strip()
                if not text_ar and text_en:
                    text_ar = text_en
                bab_id = str(h.get("chapterId", ""))
                chapter_id = chapter_key_map.get((kitab_number, bab_id))
                narrator = extract_narrator(text_en or "")

                conn.execute(
                    """INSERT INTO hadiths(
                        book_id, chapter_id, hadith_number,
                        kitab_number, kitab_title_en, bab_number, bab_title_en, bab_title_ar,
                        text_ar, text_en, narrator, reference_url, source_provider,
                        arabic_urn, english_urn
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (
                        book_id,
                        chapter_id,
                        hn,
                        kitab_number,
                        kitab_en or None,
                        bab_id or None,
                        (en.get("chapterTitle") or "").strip() or None,
                        (ar.get("chapterTitle") or "").strip() or None,
                        text_ar,
                        text_en,
                        narrator,
                        ref_url,
                        manifest["primary_provider"],
                        ar.get("urn"),
                        en.get("urn"),
                    ),
                )
                hid = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
                grades_blob = insert_grades(conn, hid, en.get("grades") or [], ar.get("grades") or [])
                blob = f"{book['name_en']} {hn} {narrator or ''} {grades_blob}"
                conn.execute(
                    """INSERT INTO hadith_fts(
                        hadith_id, book_slug, hadith_number, text_ar, text_en, text_ur,
                        narrator, grades_blob, search_blob
                    ) VALUES (?,?,?,?,?,?,?,?,?)""",
                    (hid, slug, hn, text_ar, text_en or "", "", narrator or "", grades_blob, blob),
                )
                total_hadiths += 1

            if sample_limit is not None and total_hadiths >= sample_limit:
                break

        conn.execute(
            "UPDATE books SET hadith_count=?, chapter_count=? WHERE id=?",
            (
                conn.execute("SELECT COUNT(*) FROM hadiths WHERE book_id=?", (book_id,)).fetchone()[0],
                chapter_count,
                book_id,
            ),
        )
        print(f"  {conn.execute('SELECT hadith_count FROM books WHERE id=?', (book_id,)).fetchone()[0]} hadiths, {chapter_count} chapters")

        if sample_limit is not None and total_hadiths >= sample_limit:
            print(f"Sample limit reached ({sample_limit}).")
            break

    conn.execute("INSERT INTO meta(key,value) VALUES (?,?)", ("hadith_count", str(total_hadiths)))
    conn.commit()
    conn.close()

    gz_path = output.with_suffix(output.suffix + ".gz")
    with open(output, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        f_out.write(f_in.read())

    print(f"\nDone: {output} ({total_hadiths} hadiths, {output.stat().st_size / 1024 / 1024:.2f} MB)")
    print(f"  Compressed: {gz_path} ({gz_path.stat().st_size / 1024 / 1024:.2f} MB)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build hadith.db from Sunnah.com (authenticated source only)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--sample", type=int, default=None, help="Limit total hadiths (for testing)")
    args = parser.parse_args()
    build(args.output, sample_limit=args.sample)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
