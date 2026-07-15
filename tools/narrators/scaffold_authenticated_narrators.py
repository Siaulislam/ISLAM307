#!/usr/bin/env python3
"""Scaffold narrator identity records from authenticated Hadith packs ONLY.

POLICY (STRICT):
  - Never invent biographies, kunyah, dates, teachers, students, or reliability with AI.
  - Never use Wikipedia, blogs, forums, or unverified websites.
  - Identity strings come ONLY from authenticated hadith.db / preview hadith packs
    (fawazahmed0/hadith-api@1 narrator field + extracted Arabic isnad ravi_chain).
  - Classical biography fields stay EMPTY until a licensed/research import is supplied
    (same procedure as Bukhari Hadith 1 Ibarat research file).
  - Preserves existing Bukhari Hadith 1 classical import rows and relations.

Usage:
  python3 tools/narrators/scaffold_authenticated_narrators.py
"""

from __future__ import annotations

import gzip
import json
import os
import re
import sqlite3
import tempfile
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
NARR_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"
OUT_DB = ROOT / "app" / "assets" / "databases" / "narrators.db"
OUT_GZ = NARR_GZ
PREVIEW_HADITH = ROOT / "preview" / "library" / "data" / "hadith"
PREVIEW_CATALOG = ROOT / "preview" / "library" / "data" / "narrators" / "catalog.json.gz"
REPORT = ROOT / "reports" / "verification" / "NARRATOR_SCAFFOLD_AUTHENTICATED.md"
SOURCES_JSON = ROOT / "app" / "assets" / "modules" / "narrators_sources.json"

BOOKS = ("bukhari", "muslim", "abudawud", "tirmidhi")
BATCH = "authenticated_attribution_scaffold_2026-07-12"
AR_RE = re.compile(r"[\u0600-\u06FF]")

# Extra approved Sunni rijāl titles requested for the catalog (still license-gated).
EXTRA_SOURCES = [
    (11, "al-istiab", "الاستيعاب في معرفة الأصحاب", "Al-Isti'ab fi Ma'rifat al-Ashab", "Ibn Abd al-Barr", "ابن عبد البر", 11),
    (12, "usd-al-ghabah", "أسد الغابة في معرفة الصحابة", "Usd al-Ghabah fi Ma'rifat al-Sahabah", "Ibn al-Athir", "ابن الأثير", 12),
    (13, "fath-al-bari", "فتح الباري شرح صحيح البخاري", "Fath al-Bari", "Imam Ibn Hajar al-Asqalani", "ابن حجر العسقلاني", 13),
]


def normalize_key(raw: str) -> str:
    s = raw.strip().lower()
    s = s.replace("ʼ", "'").replace("`", "'").replace("´", "'")
    s = re.sub(r"[^\w\u0600-\u06ff\s-]", " ", s, flags=re.UNICODE)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def slugify(raw: str, used: set[str]) -> str:
    s = unicodedata.normalize("NFKD", raw)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.lower()
    s = re.sub(r"[^a-z0-9\u0600-\u06ff]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    if not s:
        s = "narrator"
    # ASCII-only slug for stability in URLs
    ascii_slug = re.sub(r"[^a-z0-9-]+", "", s) or "narrator"
    base = ascii_slug[:80]
    candidate = base
    i = 2
    while candidate in used:
        candidate = f"{base}-{i}"
        i += 1
    used.add(candidate)
    return candidate


def open_gz_db(path: Path) -> tuple[sqlite3.Connection, Path]:
    raw = gzip.decompress(path.read_bytes())
    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.write(fd, raw)
    os.close(fd)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn, Path(tmp)


def ensure_extra_sources(conn: sqlite3.Connection) -> None:
    for row in EXTRA_SOURCES:
        exists = conn.execute("SELECT 1 FROM sources WHERE id=?", (row[0],)).fetchone()
        if exists:
            continue
        conn.execute(
            """
            INSERT INTO sources(
              id, slug, name_ar, name_en, author_en, author_ar, sort_order,
              license_status, attribution, notes, approved
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'permission_required', ?, ?, 1)
            """,
            (
                row[0],
                row[1],
                row[2],
                row[3],
                row[4],
                row[5],
                row[6],
                f"{row[3]} — {row[4]}. Use only with license/permission for intended distribution.",
                "Approved classical Sunni reference. Biography text not bundled until licensed import.",
            ),
        )


def collect_identities() -> tuple[dict[str, dict], list[tuple[str, int, str, str, int | None]]]:
    """Return (identities_by_norm, relations_todo).

    identities: norm -> {display, name_en?, name_ar?}
    relations_todo: (book, hadith_n, role, display_name, position|None)
    """
    identities: dict[str, dict] = {}
    relations: list[tuple[str, int, str, str, int | None]] = []

    def add_identity(display: str) -> str:
        display = display.strip()
        if not display:
            return ""
        key = normalize_key(display)
        if not key:
            return ""
        slot = identities.setdefault(key, {"display": display, "name_en": "", "name_ar": ""})
        if AR_RE.search(display):
            if not slot["name_ar"]:
                slot["name_ar"] = display
        else:
            if not slot["name_en"]:
                slot["name_en"] = display
        return key

    # Primary attributions from authenticated hadith.db
    hconn, htmp = open_gz_db(HADITH_GZ)
    try:
        book_ids = {r["slug"]: r["id"] for r in hconn.execute("SELECT id, slug FROM books")}
        for slug in BOOKS:
            bid = book_ids[slug]
            for row in hconn.execute(
                """
                SELECT hadith_number, narrator
                FROM hadiths
                WHERE book_id=? AND narrator IS NOT NULL AND TRIM(narrator) != ''
                """,
                (bid,),
            ):
                name = row["narrator"].strip()
                key = add_identity(name)
                if key:
                    relations.append((slug, int(row["hadith_number"]), "primary", name, None))
    finally:
        hconn.close()
        htmp.unlink(missing_ok=True)

    # Authenticated Arabic isnad chain names from preview packs (already extracted, never AI)
    for slug in BOOKS:
        path = PREVIEW_HADITH / f"{slug}.json.gz"
        if not path.exists():
            continue
        data = json.loads(gzip.decompress(path.read_bytes()))
        for h in data.get("hadiths") or []:
            n = int(h.get("n") or 0)
            if not n:
                continue
            chain = h.get("ravi_chain") or []
            for idx, raw in enumerate(chain):
                name = str(raw).strip()
                key = add_identity(name)
                if key:
                    relations.append((slug, n, "in_isnad", name, idx + 1))

    return identities, relations


def main() -> int:
    if not NARR_GZ.exists():
        raise SystemExit(f"Missing {NARR_GZ}")
    if not HADITH_GZ.exists():
        raise SystemExit(f"Missing {HADITH_GZ}")

    identities, relations_todo = collect_identities()
    print(f"Collected {len(identities)} unique authenticated identity strings")
    print(f"Collected {len(relations_todo)} hadith↔narrator mapping rows (pre-dedupe)")

    conn, tmp = open_gz_db(NARR_GZ)
    try:
        ensure_extra_sources(conn)

        # Existing alias → narrator_id
        alias_to_id: dict[str, int] = {}
        for r in conn.execute("SELECT narrator_id, alias_normalized FROM name_aliases"):
            alias_to_id[r["alias_normalized"]] = int(r["narrator_id"])

        used_slugs = {r["slug"] for r in conn.execute("SELECT slug FROM narrators")}
        next_id = (conn.execute("SELECT COALESCE(MAX(id), 0) FROM narrators").fetchone()[0] or 0) + 1

        created = 0
        reused = 0
        norm_to_id: dict[str, int] = {}

        for key, meta in sorted(identities.items(), key=lambda kv: kv[1]["display"].lower()):
            if key in alias_to_id:
                nid = alias_to_id[key]
                norm_to_id[key] = nid
                reused += 1
                continue

            display = meta["display"]
            name_en = meta["name_en"] or ("" if AR_RE.search(display) else display)
            name_ar = meta["name_ar"] or (display if AR_RE.search(display) else "")
            slug = slugify(name_en or name_ar or display, used_slugs)
            conn.execute(
                """
                INSERT INTO narrators(
                  id, slug, name_ar, name_ur, name_en, full_name,
                  kunyah, laqab, nasab, birth_text, death_text,
                  birth_hijri, death_hijri, city, country, generation,
                  is_companion, is_tabii, is_tab_tabii, timeline_notes, import_batch
                ) VALUES (?, ?, ?, NULL, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, NULL, ?)
                """,
                (next_id, slug, name_ar or None, name_en or None, BATCH),
            )
            for lang, alias in (("en", name_en), ("ar", name_ar), ("en", display), ("ar", display)):
                a = (alias or "").strip()
                if not a:
                    continue
                nk = normalize_key(a)
                if not nk:
                    continue
                try:
                    conn.execute(
                        """
                        INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized)
                        VALUES (?, ?, ?, ?)
                        """,
                        (next_id, lang, a, nk),
                    )
                except sqlite3.IntegrityError:
                    pass
                alias_to_id.setdefault(nk, next_id)
            norm_to_id[key] = next_id
            next_id += 1
            created += 1

        # Refresh alias map after inserts
        for r in conn.execute("SELECT narrator_id, alias_normalized FROM name_aliases"):
            alias_to_id[r["alias_normalized"]] = int(r["narrator_id"])

        # Skip relation inserts for hadiths that already have a mapped chain (e.g. Bukhari 1)
        existing_hadith = {
            (r["book_slug"], int(r["hadith_number"]))
            for r in conn.execute("SELECT DISTINCT book_slug, hadith_number FROM hadith_relations")
        }

        inserted_rel = 0
        skipped_existing = 0
        missing_id = 0
        seen_rel: set[tuple] = set()

        for book, num, role, display, pos in relations_todo:
            if (book, num) in existing_hadith and book == "bukhari" and num == 1:
                skipped_existing += 1
                continue
            # For hadiths that already have full imported chains, still allow primary-only
            # if missing — but Bukhari 1 is fully imported; skip all its new rows above.

            key = normalize_key(display)
            nid = alias_to_id.get(key) or norm_to_id.get(key)
            if not nid:
                missing_id += 1
                continue
            rel_key = (book, num, nid, role)
            if rel_key in seen_rel:
                continue
            # DB unique check
            exists = conn.execute(
                """
                SELECT 1 FROM hadith_relations
                WHERE book_slug=? AND hadith_number=? AND narrator_id=? AND role=?
                """,
                (book, num, nid, role),
            ).fetchone()
            if exists:
                continue
            seen_rel.add(rel_key)
            conn.execute(
                """
                INSERT INTO hadith_relations(book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (book, num, nid, role, pos, BATCH),
            )
            inserted_rel += 1

        n_count = conn.execute("SELECT COUNT(*) FROM narrators").fetchone()[0]
        m_count = conn.execute("SELECT COUNT(*) FROM hadith_relations").fetchone()[0]
        bio_count = conn.execute(
            """
            SELECT COUNT(*) FROM narrators
            WHERE COALESCE(kunyah,'') != '' OR COALESCE(nasab,'') != ''
               OR COALESCE(birth_text,'') != '' OR COALESCE(death_text,'') != ''
               OR COALESCE(generation,'') != ''
            """
        ).fetchone()[0]

        now = datetime.now(timezone.utc).isoformat()
        meta = {
            "batch": BATCH,
            "at": now,
            "unique_identities": len(identities),
            "narrators_created": created,
            "narrators_reused": reused,
            "relations_inserted": inserted_rel,
            "relations_skipped_bukhari_1": skipped_existing,
            "relations_missing_id": missing_id,
            "narrators_total": n_count,
            "relations_total": m_count,
            "with_classical_bio_fields": bio_count,
            "policy": "Scaffolded identity + mappings from authenticated hadith packs only. Classical bio fields empty unless licensed/research import.",
        }
        conn.execute(
            "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("biography_rows", str(bio_count)),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("hadith_mappings", str(m_count)),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("last_import", json.dumps(meta, ensure_ascii=False)),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (
                "import_note",
                "Identity scaffold from authenticated hadith narrator/isnad strings. "
                "Classical rijāl biographies require licensed/research imports (Bukhari 1 procedure). "
                "Never invent with AI.",
            ),
        )
        conn.commit()

        # Write preview catalog (identity fields only + any classical fields already present)
        catalog_narrators = {}
        for r in conn.execute(
            """
            SELECT id, slug, name_ar, name_ur, name_en, full_name, kunyah, laqab, nasab,
                   birth_text, death_text, birth_hijri, death_hijri, city, country, generation,
                   is_companion, is_tabii, is_tab_tabii, timeline_notes, import_batch
            FROM narrators
            """
        ):
            d = dict(r)
            d["is_companion"] = bool(d["is_companion"])
            d["is_tabii"] = bool(d["is_tabii"])
            d["is_tab_tabii"] = bool(d["is_tab_tabii"])
            catalog_narrators[str(d["id"])] = d

        alias_map = {
            r["alias_normalized"]: int(r["narrator_id"])
            for r in conn.execute("SELECT alias_normalized, narrator_id FROM name_aliases")
        }
        primary_map: dict[str, int] = {}
        for r in conn.execute(
            """
            SELECT book_slug, hadith_number, narrator_id
            FROM hadith_relations
            WHERE role='primary'
            """
        ):
            primary_map[f"{r['book_slug']}:{int(r['hadith_number'])}"] = int(r["narrator_id"])

        catalog = {
            "policy": meta["policy"],
            "batch": BATCH,
            "generated_at": now,
            "narrators": catalog_narrators,
            "aliases": alias_map,
            "primary_by_hadith": primary_map,
        }
        PREVIEW_CATALOG.parent.mkdir(parents=True, exist_ok=True)
        with gzip.open(PREVIEW_CATALOG, "wb", compresslevel=9) as gz:
            gz.write(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

        # Persist DB as gzip asset
        conn.close()
        raw = tmp.read_bytes()
        with gzip.open(OUT_GZ, "wb", compresslevel=9) as gz:
            gz.write(raw)
        tmp.unlink(missing_ok=True)
        if OUT_DB.exists():
            OUT_DB.unlink()

        # Update narrators_sources.json pack flags
        if SOURCES_JSON.exists():
            src = json.loads(SOURCES_JSON.read_text(encoding="utf-8"))
            pack = src.setdefault("pack", {})
            pack["has_biography_rows"] = bio_count > 0
            pack["has_hadith_mappings"] = m_count > 0
            pack["last_import_batch"] = BATCH
            pack["notes"] = (
                f"Authenticated identity scaffold for {n_count} narrators across four Hadith books. "
                f"Classical biography fields populated only where licensed/research import exists "
                f"(currently {bio_count} rows, including Bukhari Hadith 1). Never AI-invented."
            )
            existing_slugs = {s.get("slug") for s in src.get("approved_sources", [])}
            for row in EXTRA_SOURCES:
                if row[1] in existing_slugs:
                    continue
                src.setdefault("approved_sources", []).append(
                    {
                        "slug": row[1],
                        "name_en": row[3],
                        "name_ar": row[2],
                        "author": row[4],
                        "license_status": "permission_required",
                    }
                )
            SOURCES_JSON.write_text(json.dumps(src, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(
            f"""# Narrator Authenticated Scaffold Report

Batch: `{BATCH}`

## Policy

- Never invent narrator biographies with AI.
- Scaffold identity strings ONLY from authenticated hadith packs (`narrator` field + Arabic `ravi_chain`).
- Classical fields (kunyah, nasab, birth/death, jarḥ wa taʿdīl, teachers, students, books) stay **empty** until a Bukhari-1-style licensed/research import is provided.
- Wikipedia / blogs / unverified sites / non-Sunni sources are forbidden.

## Results

| Metric | Count |
|--------|------:|
| Unique authenticated identity strings | {len(identities)} |
| Narrator rows created this run | {created} |
| Existing narrators reused (incl. Bukhari 1) | {reused} |
| Narrator rows total | {n_count} |
| Hadith↔narrator relations inserted | {inserted_rel} |
| Relations total | {m_count} |
| Rows with any classical bio field | {bio_count} |

## Books covered

Bukhari, Muslim, Abu Dawud, Tirmidhi — every authenticated primary attribution and isnad-chain name now has a Narrator Detail page shell using the standard راوی معلومات table.

## Next imports (required for full classical profiles)

Provide research/licensed extracts (same procedure as `data/narrators/imports/bukhari_1_sanad_urdu.txt`) citing:

Tahdhib al-Kamal, Tahdhib al-Tahdhib, Taqrib al-Tahdhib, Al-Jarh wa al-Ta'dil, Siyar A'lam al-Nubala', Tarikh al-Kabir, Al-Isabah, Al-Isti'ab, Usd al-Ghabah, Fath al-Bari.

Until then, Detail pages show Narrator ID + authenticated name attribution only; other fields remain blank by design.
""",
            encoding="utf-8",
        )

        print(json.dumps(meta, indent=2, ensure_ascii=False))
        print(f"Wrote {OUT_GZ} ({OUT_GZ.stat().st_size} bytes)")
        print(f"Wrote {PREVIEW_CATALOG} ({PREVIEW_CATALOG.stat().st_size} bytes)")
        print(f"Wrote {REPORT}")
        return 0
    except Exception:
        conn.close()
        tmp.unlink(missing_ok=True)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
