#!/usr/bin/env python3
"""Rebuild Bukhari Knowledge (abs 59–134) sanad packs from Arabic Prophet-cutoff extraction."""

from __future__ import annotations

import gzip
import json
import os
import re
import sqlite3
import sys
import tempfile
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from hadith.hadith_meta import extract_ravi_chain  # noqa: E402

NARR_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
PREVIEW_HADITH = ROOT / "preview" / "library" / "data" / "hadith" / "bukhari.json.gz"
PREVIEW_NARR = ROOT / "preview" / "library" / "data" / "narrators"
CATALOG = PREVIEW_NARR / "catalog.json.gz"
MANIFEST = ROOT / "preview" / "library" / "data" / "manifest.json"
CHAINS_JSON = ROOT / "data" / "narrators" / "imports" / "bukhari_ilm_1_76_chains.json"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_ILM_ARABIC_EXTRACT_SANAD.md"
BATCH = "bukhari_ilm_arabic_prophet_cutoff_2026-07-12"
BUKHARI_ID = 1
ABS_START, ABS_END = 59, 134


def strip_diac(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


def normalize_key(raw: str) -> str:
    s = raw.strip().lower()
    s = re.sub(r"[^\w\u0600-\u06ff\s-]", " ", s, flags=re.UNICODE)
    return re.sub(r"\s+", " ", s).strip()


def slugify(raw: str, used: set[str]) -> str:
    s = unicodedata.normalize("NFKD", raw)
    s = "".join(ch for ch in s if not unicodedata.combining(ch)).lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-") or "narrator"
    base = s[:80]
    cand, i = base, 2
    while cand in used:
        cand = f"{base}-{i}"
        i += 1
    used.add(cand)
    return cand


def open_gz(path: Path):
    raw = gzip.decompress(path.read_bytes())
    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.write(fd, raw)
    os.close(fd)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn, Path(tmp)


def ar_to_ur(ar: str) -> str:
    s = (ar or "").strip()
    for a, b in [
        ("أ", "ا"),
        ("إ", "ا"),
        ("آ", "آ"),
        ("ة", "ہ"),
        ("ى", "ی"),
        ("ي", "ی"),
        ("ك", "ک"),
        ("ه", "ہ"),
    ]:
        s = s.replace(a, b)
    s = s.replace("اللیث", "لیث").replace("الأعمش", "اعمش")
    return re.sub(r"\s+", " ", s).strip()


def find_or_create(conn, ur: str, ar: str, used_slugs: set[str]) -> int:
    for alias in (ur, ar):
        if not alias:
            continue
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
            (normalize_key(alias),),
        ).fetchone()
        if row:
            nid = int(row["narrator_id"])
            ur_nk = normalize_key(ur)
            if not conn.execute(
                "SELECT 1 FROM name_aliases WHERE narrator_id=? AND alias_normalized=?",
                (nid, ur_nk),
            ).fetchone():
                conn.execute(
                    "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                    (nid, "ur", ur, ur_nk),
                )
            return nid
    next_id = (conn.execute("SELECT COALESCE(MAX(id),0) FROM narrators").fetchone()[0] or 0) + 1
    slug = slugify(ar or ur, used_slugs)
    conn.execute(
        """
        INSERT INTO narrators(
          id, slug, name_ar, name_ur, name_en, full_name,
          kunyah, laqab, nasab, birth_text, death_text, birth_hijri, death_hijri,
          city, country, generation, is_companion, is_tabii, is_tab_tabii,
          timeline_notes, import_batch
        ) VALUES (?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, NULL, ?)
        """,
        (next_id, slug, ar or None, ur or None, BATCH),
    )
    for lang, alias in (("ar", ar), ("ur", ur)):
        if not alias:
            continue
        try:
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (next_id, lang, alias, normalize_key(alias)),
            )
        except sqlite3.IntegrityError:
            pass
    return next_id


def main() -> int:
    hconn, htmp = open_gz(HADITH_GZ)
    arabic = {}
    chains_ar = {}
    for num in range(ABS_START, ABS_END + 1):
        row = hconn.execute(
            "SELECT text_ar FROM hadiths WHERE book_id=1 AND hadith_number=?",
            (num,),
        ).fetchone()
        text = row["text_ar"] if row else ""
        arabic[num] = text
        names = extract_ravi_chain(text)
        chains_ar[num] = names
        print(f"abs {num}: {len(names)} → {' ← '.join(names)}")
    hconn.close()
    htmp.unlink(missing_ok=True)

    # Example self-check
    ex = (
        "حدثنا عبد الله بن عبد الوهاب، قال حدثنا حماد، عن أيوب، عن محمد، "
        "عن ابن أبي بكرة، عن أبي بكرة، ذكر النبي صلى الله عليه وسلم"
    )
    got = extract_ravi_chain(ex)
    expected = [
        "عبد الله بن عبد الوهاب",
        "حماد",
        "أيوب",
        "محمد",
        "ابن أبي بكرة",
        "أبي بكرة",
    ]
    assert got == expected, f"Example failed: {got}"

    conn, tmp = open_gz(NARR_GZ)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadith_relations)")}
    if "display_name_ur" not in cols:
        conn.execute("ALTER TABLE hadith_relations ADD COLUMN display_name_ur TEXT")

    # Ensure unique on isnad_position (may already be migrated).
    old_sql = conn.execute("SELECT sql FROM sqlite_master WHERE name='hadith_relations'").fetchone()[0]
    if "UNIQUE (book_slug, hadith_number, narrator_id, role)" in (old_sql or ""):
        conn.execute("DROP TABLE IF EXISTS hadith_relations_v2")
        conn.execute(
            """
            CREATE TABLE hadith_relations_v2 (
              id INTEGER PRIMARY KEY,
              book_slug TEXT NOT NULL,
              hadith_number INTEGER NOT NULL,
              narrator_id INTEGER NOT NULL,
              role TEXT NOT NULL DEFAULT 'primary',
              isnad_position INTEGER,
              mapping_source TEXT NOT NULL,
              display_name_ur TEXT,
              UNIQUE (book_slug, hadith_number, isnad_position)
            )
            """
        )
        conn.execute(
            """
            INSERT INTO hadith_relations_v2
            SELECT id, book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source, display_name_ur
            FROM hadith_relations
            """
        )
        conn.execute("DROP TABLE hadith_relations")
        conn.execute("ALTER TABLE hadith_relations_v2 RENAME TO hadith_relations")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_hadith_rel_lookup ON hadith_relations(book_slug, hadith_number)"
        )

    used_slugs = {r["slug"] for r in conn.execute("SELECT slug FROM narrators")}
    packs = {}
    export = []

    for num, ar_names in chains_ar.items():
        conn.execute(
            "DELETE FROM hadith_relations WHERE book_slug='bukhari' AND hadith_number=?",
            (num,),
        )
        # compiler + extracted chain
        items = [{"ur": "امام بخاریؒ", "ar": "", "role": "compiler", "nid": BUKHARI_ID}]
        for i, ar in enumerate(ar_names):
            ur = ar_to_ur(ar)
            role = "primary" if i == len(ar_names) - 1 else "in_isnad"
            items.append({"ur": ur, "ar": ar, "role": role, "nid": None})

        pack_chain = []
        for pos, item in enumerate(items, 1):
            if item["nid"]:
                nid = item["nid"]
            else:
                nid = find_or_create(conn, item["ur"], item["ar"], used_slugs)
            conn.execute(
                """
                INSERT INTO hadith_relations(
                  book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source, display_name_ur
                ) VALUES ('bukhari', ?, ?, ?, ?, ?, ?)
                """,
                (num, nid, item["role"], pos, BATCH, item["ur"]),
            )
            n = dict(conn.execute("SELECT * FROM narrators WHERE id=?", (nid,)).fetchone())
            pack_chain.append(
                {
                    "order": pos,
                    "role": item["role"],
                    "narrator_id": nid,
                    "slug": n["slug"],
                    "name_ar": item["ar"] or n["name_ar"] or "",
                    "name_en": n["name_en"] or "",
                    "name_ur": item["ur"],
                    "full_name": n["full_name"] or "",
                    "kunyah": n["kunyah"] or "",
                    "laqab": n["laqab"] or "",
                    "nasab": n["nasab"] or "",
                    "birth_text": n["birth_text"] or "",
                    "death_text": n["death_text"] or "",
                    "generation": n["generation"] or "",
                    "is_companion": bool(n["is_companion"]),
                    "kitab": "علم",
                    "kitab_local_number": num - 58,
                }
            )
        packs[num] = pack_chain
        export.append(
            {
                "abs": num,
                "local": num - 58,
                "chain": [{"ur": c["name_ur"], "ar": c["name_ar"], "role": c["role"]} for c in pack_chain],
                "source": "arabic_prophet_cutoff",
            }
        )

    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (
            "last_import",
            json.dumps(
                {
                    "batch": BATCH,
                    "at": now,
                    "kitab": "Knowledge / علم",
                    "note": "Arabic extraction until first Prophet ﷺ marker",
                },
                ensure_ascii=False,
            ),
        ),
    )
    conn.commit()

    PREVIEW_NARR.mkdir(parents=True, exist_ok=True)
    for num, chain in packs.items():
        payload = {
            "book_slug": "bukhari",
            "kitab": "علم",
            "kitab_en": "Knowledge",
            "kitab_local_number": num - 58,
            "hadith_number": num,
            "policy": "Arabic isnad until first Prophet ﷺ; Prophet excluded; Matn ignored.",
            "arabic_ibarat": arabic[num],
            "chain": chain,
        }
        (PREVIEW_NARR / f"bukhari-{num}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    CHAINS_JSON.write_text(json.dumps(export, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    hdata = json.loads(gzip.decompress(PREVIEW_HADITH.read_bytes()))
    by_n = {h["n"]: h for h in hdata["hadiths"]}
    for num, chain in packs.items():
        h = by_n.get(num)
        if not h:
            continue
        primary = next(c for c in chain if c["role"] == "primary")
        h["ravi"] = primary["name_ur"]
        h["narrator"] = primary["name_en"] or primary["name_ur"]
        h["ravi_chain"] = [c["name_ar"] or c["name_ur"] for c in chain if c["role"] != "compiler"]
        h["ravi_by_lang"] = {
            "ar": [c["name_ar"] or c["name_ur"] for c in chain if c["role"] != "compiler"],
            "en": [c["name_en"] or c["name_ur"] for c in chain if c["role"] != "compiler"],
            "ur": [c["name_ur"] for c in chain if c["role"] != "compiler"],
        }
    with gzip.open(PREVIEW_HADITH, "wb", compresslevel=9) as gz:
        gz.write(json.dumps(hdata, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

    if CATALOG.exists():
        cat = json.loads(gzip.decompress(CATALOG.read_bytes()))
        for num, chain in packs.items():
            for c in chain:
                row = dict(conn.execute("SELECT * FROM narrators WHERE id=?", (c["narrator_id"],)).fetchone())
                cat.setdefault("narrators", {})[str(c["narrator_id"])] = {
                    **{k: row[k] for k in row.keys()},
                    "is_companion": bool(row["is_companion"]),
                    "is_tabii": bool(row["is_tabii"]),
                    "is_tab_tabii": bool(row["is_tab_tabii"]),
                }
                cat.setdefault("aliases", {})[normalize_key(c["name_ur"])] = c["narrator_id"]
            primary = next(c for c in chain if c["role"] == "primary")
            cat.setdefault("primary_by_hadith", {})[f"bukhari:{num}"] = primary["narrator_id"]
        with gzip.open(CATALOG, "wb", compresslevel=9) as gz:
            gz.write(json.dumps(cat, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

    man = json.loads(MANIFEST.read_text(encoding="utf-8"))
    narr = man.setdefault("narrators", {})
    for num, chain in packs.items():
        narr[f"bukhari-{num}"] = {
            "book": "bukhari",
            "kitab": "Knowledge",
            "kitab_local": num - 58,
            "hadith": num,
            "chain_length": len(chain),
        }
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False) + "\n", encoding="utf-8")

    conn.close()
    with gzip.open(NARR_GZ, "wb", compresslevel=9) as gz:
        gz.write(tmp.read_bytes())
    tmp.unlink(missing_ok=True)

    lines = [
        "# Bukhari Knowledge Arabic Prophet-cutoff Sanad Extract",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Rule: extract every narrator from the start of `text_ar` until the first",
        "النبي / رسول الله / محمد صلى الله عليه وسلم. Prophet ﷺ excluded.",
        "",
        "## Example check",
        "",
        f"PASS → {' ← '.join(expected)}",
        "",
        "## Chains (Ilm 1–76 / abs 59–134)",
        "",
    ]
    for num, chain in packs.items():
        lines.append(f"### Ilm {num-58} / Absolute {num}")
        lines.append("")
        for c in chain:
            lines.append(f"{c['order']}. {c['name_ur']}")
        lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
