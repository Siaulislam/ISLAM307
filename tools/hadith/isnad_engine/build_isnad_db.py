#!/usr/bin/env python3
"""Build isnad.db from hadith.db.gz using the Arabic Isnad Engine."""

from __future__ import annotations

import argparse
import gzip
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "hadith"))

from isnad_engine.compilers import COMPILERS  # noqa: E402
from isnad_engine.engine import IsnadEngine  # noqa: E402
from isnad_engine.confidence import REVIEW_THRESHOLD  # noqa: E402

SCHEMA = Path(__file__).with_name("schema_isnad.sql")
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
OUT_DB = ROOT / "app" / "assets" / "databases" / "isnad.db"
OUT_GZ = ROOT / "app" / "assets" / "databases" / "isnad.db.gz"


def open_hadith() -> sqlite3.Connection:
    raw = gzip.decompress(HADITH_GZ.read_bytes())
    tmp = Path(tempfile.mkstemp(suffix=".db")[1])
    tmp.write_bytes(raw)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit-per-book", type=int, default=0, help="0 = all")
    ap.add_argument("--books", default="", help="comma slugs; empty = all present")
    ap.add_argument("--out", type=Path, default=OUT_DB)
    args = ap.parse_args()

    hadith = open_hadith()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.out.exists():
        args.out.unlink()
    isnad = sqlite3.connect(args.out)
    isnad.execute("PRAGMA foreign_keys = OFF")
    isnad.executescript(SCHEMA.read_text(encoding="utf-8"))

    engine = IsnadEngine()
    # Seed compilers (compiler ≠ chain link). Narrator IDs filled after registry export.
    for slug, info in COMPILERS.items():
        if info.name_ar:
            engine.registry.get_or_create(info.name_ar)
        isnad.execute(
            "INSERT OR REPLACE INTO compilers(book_slug, name_ar, name_en, narrator_id) VALUES (?,?,?,NULL)",
            (slug, info.name_ar, info.name_en),
        )
    compiler_ids = {
        r[0]: r[1]
        for r in isnad.execute("SELECT book_slug, id FROM compilers")
    }

    books = list(
        hadith.execute("SELECT id, slug FROM books ORDER BY sort_order")
    )
    if args.books:
        want = {s.strip() for s in args.books.split(",") if s.strip()}
        books = [b for b in books if b["slug"] in want]

    stats = {"books": {}, "review_queue": 0, "sanads": 0, "narrators": 0}
    pending: list[tuple[str, int, object]] = []

    for book in books:
        slug = book["slug"]
        q = (
            "SELECT hadith_number, text_ar FROM hadiths WHERE book_id=? "
            "ORDER BY hadith_number, id"
        )
        rows = hadith.execute(q, (book["id"],)).fetchall()
        seen: set[int] = set()
        uniq = []
        for r in rows:
            if r["hadith_number"] in seen:
                continue
            seen.add(r["hadith_number"])
            uniq.append(r)
            if args.limit_per_book and len(uniq) >= args.limit_per_book:
                break
        for r in uniq:
            result = engine.parse(
                text_ar=r["text_ar"],
                book_slug=slug,
                hadith_number=r["hadith_number"],
            )
            pending.append((slug, r["hadith_number"], result))

    # Narrators first (IDs referenced by links).
    engine.registry.export_sqlite(isnad)
    for slug, info in COMPILERS.items():
        rec = engine.registry.lookup_key(info.name_ar) if info.name_ar else None
        if rec:
            isnad.execute(
                "UPDATE compilers SET narrator_id=? WHERE book_slug=?",
                (rec.id, slug),
            )

    for slug, hadith_number, result in pending:
        book_stats = stats["books"].setdefault(slug, {"sanads": 0, "review": 0})
        for chain in result.chains:
            cur = isnad.execute(
                """
                INSERT INTO hadith_sanads(
                  book_slug, hadith_number, chain_index, compiler_id,
                  isnad_ar, matn_ar, confidence, review_status, review_reasons
                ) VALUES (?,?,?,?,?,?,?,?,?)
                """,
                (
                    slug,
                    hadith_number,
                    chain.chain_index,
                    compiler_ids.get(slug),
                    chain.isnad_ar,
                    chain.matn_ar,
                    chain.confidence,
                    "pending",  # never auto-approve
                    json.dumps(chain.review_reasons, ensure_ascii=False),
                ),
            )
            sanad_id = cur.lastrowid
            book_stats["sanads"] += 1
            stats["sanads"] += 1
            for lnk in chain.links:
                isnad.execute(
                    """
                    INSERT INTO hadith_sanad_links(
                      sanad_id, position, narrator_id, transmission_verb,
                      relation_type, relative_to_position, resolved_from_relative,
                      surface_form
                    ) VALUES (?,?,?,?,?,?,?,?)
                    """,
                    (
                        sanad_id,
                        lnk.position,
                        lnk.ref.narrator_id,
                        lnk.transmission_verb,
                        lnk.ref.relation_type,
                        lnk.ref.relative_to_position,
                        1 if lnk.ref.resolved_from_relative else 0,
                        lnk.ref.surface_form,
                    ),
                )
            if chain.confidence < REVIEW_THRESHOLD:
                isnad.execute(
                    """
                    INSERT INTO sanad_review_queue(
                      book_slug, hadith_number, sanad_id, confidence, reason, status
                    ) VALUES (?,?,?,?,?, 'open')
                    """,
                    (
                        slug,
                        hadith_number,
                        sanad_id,
                        chain.confidence,
                        ";".join(chain.review_reasons) or "below_threshold",
                    ),
                )
                book_stats["review"] += 1
                stats["review_queue"] += 1

    isnad.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES ('schema','isnad_engine_v1')"
    )
    isnad.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES ('review_threshold',?)",
        (str(REVIEW_THRESHOLD),),
    )
    isnad.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES ('stats',?)",
        (json.dumps(stats, ensure_ascii=False),),
    )
    isnad.commit()
    stats["narrators"] = len(engine.registry)

    # gzip copy for app assets
    OUT_GZ.write_bytes(gzip.compress(args.out.read_bytes(), compresslevel=9))
    report = ROOT / "reports" / "verification" / "ISNAD_ENGINE_BUILD.json"
    report.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    print(f"Wrote {args.out} and {OUT_GZ}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
