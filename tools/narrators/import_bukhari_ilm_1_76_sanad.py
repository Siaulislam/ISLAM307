#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Ilm Hadith 1–76 (absolute nos. 59–134).

User-final Urdu sanad list by hadith number only.
Local N → absolute (58+N). Do not alter user wording.
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
NARR_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
SANAD_TXT = ROOT / "data" / "narrators" / "imports" / "bukhari_ilm_1_76_sanad_ur.txt"
CHAINS_JSON = ROOT / "data" / "narrators" / "imports" / "bukhari_ilm_1_76_chains.json"
PREVIEW_HADITH = ROOT / "preview" / "library" / "data" / "hadith" / "bukhari.json.gz"
PREVIEW_NARR = ROOT / "preview" / "library" / "data" / "narrators"
CATALOG = PREVIEW_NARR / "catalog.json.gz"
MANIFEST = ROOT / "preview" / "library" / "data" / "manifest.json"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_ILM_1_76_SANAD_IMPORT.md"
BATCH = "bukhari_ilm_1_76_sanad_user_final_2026-07-12"
BUKHARI_ID = 1

SHARED = {
    "امام بخاریؒ": "bukhari",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "عبداللہ بن عمرؓ": "abdullah-ibn-umar",
    "عبداللہ بن عمروؓ": "abdullah-ibn-amr",
    "عبداللہ بن مسعودؓ": "abdullah-ibn-masud",
    "عبداللہ بن عباسؓ": "abdullah-ibn-abbas",
    "ابن عباسؓ": "abdullah-ibn-abbas",
    "ابن عمرؓ": "abdullah-ibn-umar",
    "عائشہؓ": "aisha",
    "معاویہ بن ابی سفیانؓ": "muawiya",
    "نعمان بن بشیرؓ": "numan-ibn-bashir",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "زہری": "ibn-shihab-al-zuhri",
    "عروہ بن زبیر": "urwah-ibn-al-zubayr",
    "امام مالک": "malik-ibn-anas",
    "مسدد": "musaddad",
    "شعبہ": "shubah",
    "ابوالیمان": "abu-al-yaman",
    "شعیب": "shuayb",
    "لیث بن سعد": "layth-ibn-saad",
    "قتیبہ بن سعید": "qutaybah",
}


def strip_diac(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


def normalize_key(raw: str) -> str:
    s = raw.strip().lower().replace("ʼ", "'").replace("`", "'").replace("´", "'")
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


def parse_user_sanad() -> dict[int, list[str]]:
    text = SANAD_TXT.read_text(encoding="utf-8")
    blocks = re.split(r"(?=حدیث نمبر\s*\d+)", text)
    user: dict[int, list[str]] = {}
    for block in blocks:
        m = re.match(r"حدیث نمبر\s*(\d+)\s*\n([\s\S]+)", block.strip())
        if not m:
            continue
        n = int(m.group(1))
        lines = [ln.strip() for ln in m.group(2).strip().splitlines() if ln.strip()]
        user[n] = lines  # exact wording, including امام بخاریؒ
    missing = [i for i in range(1, 77) if i not in user]
    if missing:
        raise SystemExit(f"Missing user sanad numbers: {missing}")
    return user


def build_chains(user: dict[int, list[str]]) -> dict[int, list[dict]]:
    chains: dict[int, list[dict]] = {}
    export = []
    for local in range(1, 77):
        absn = 58 + local
        names = user[local]
        items = []
        for i, ur in enumerate(names):
            if i == 0 and "بخاری" in ur:
                role = "compiler"
                item = {"ur": ur, "role": role, "narrator_id": BUKHARI_ID}
            elif i == len(names) - 1:
                role = "primary"
                item = {"ur": ur, "role": role}
            else:
                role = "in_isnad"
                item = {"ur": ur, "role": role}
            items.append(item)
        chains[absn] = items
        export.append(
            {
                "abs": absn,
                "local": local,
                "chain": [{"ur": c["ur"], "role": c["role"]} for c in items],
                "source": "user_final_exact",
            }
        )
    CHAINS_JSON.write_text(json.dumps(export, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return chains


def find_or_create(conn, item, used_slugs, shared_ids):
    ur = item["ur"]
    person_key = item.get("person_key") or SHARED.get(ur)

    if item.get("narrator_id"):
        nid = int(item["narrator_id"])
        nk = normalize_key(ur)
        if not conn.execute(
            "SELECT 1 FROM name_aliases WHERE narrator_id=? AND alias_normalized=?", (nid, nk)
        ).fetchone():
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (nid, "ur", ur, nk),
            )
        return nid

    if person_key and person_key in shared_ids:
        return shared_ids[person_key]

    # Match by exact Urdu alias only (no Arabic rewriting).
    candidates = [ur]
    # Also try without parenthetical nickname for lookup, but keep display exact.
    bare = re.sub(r"\s*\([^)]*\)\s*", " ", ur).strip()
    if bare != ur:
        candidates.append(bare)

    for alias in candidates:
        nk = normalize_key(alias)
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1", (nk,)
        ).fetchone()
        if not row and alias:
            row = conn.execute(
                "SELECT narrator_id FROM name_aliases WHERE alias=? LIMIT 1", (alias,)
            ).fetchone()
        if row:
            nid = int(row["narrator_id"])
            if person_key:
                shared_ids[person_key] = nid
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
    slug = slugify(person_key or ur, used_slugs)
    conn.execute(
        """
        INSERT INTO narrators(
          id, slug, name_ar, name_ur, name_en, full_name,
          kunyah, laqab, nasab, birth_text, death_text, birth_hijri, death_hijri,
          city, country, generation, is_companion, is_tabii, is_tab_tabii,
          timeline_notes, import_batch
        ) VALUES (?, ?, NULL, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, NULL, ?)
        """,
        (next_id, slug, ur, BATCH),
    )
    try:
        conn.execute(
            "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
            (next_id, "ur", ur, normalize_key(ur)),
        )
    except sqlite3.IntegrityError:
        pass
    if person_key:
        shared_ids[person_key] = next_id
    return next_id


def main() -> int:
    user = parse_user_sanad()
    CHAINS = build_chains(user)

    hconn, htmp = open_gz(HADITH_GZ)
    arabic = {}
    for num in CHAINS:
        row = hconn.execute(
            """
            SELECT h.text_ar FROM hadiths h JOIN books b ON b.id=h.book_id
            WHERE b.slug='bukhari' AND h.hadith_number=?
            """,
            (num,),
        ).fetchone()
        arabic[num] = row["text_ar"] if row else ""
        print(f"abs {num} / Ilm {num-58}: {len(CHAINS[num])} names (user exact)")
    hconn.close()
    htmp.unlink(missing_ok=True)

    conn, tmp = open_gz(NARR_GZ)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadith_relations)")}
    if "display_name_ur" not in cols:
        conn.execute("ALTER TABLE hadith_relations ADD COLUMN display_name_ur TEXT")

    # Allow the same narrator twice in one chain (e.g. فلیح at two isnad positions).
    old_sql = conn.execute(
        "SELECT sql FROM sqlite_master WHERE name='hadith_relations'"
    ).fetchone()[0]
    if "UNIQUE (book_slug, hadith_number, narrator_id, role)" in (old_sql or ""):
        conn.execute("DROP TABLE IF EXISTS hadith_relations_v2")
        conn.execute(
            """
            CREATE TABLE hadith_relations_v2 (
              id INTEGER PRIMARY KEY,
              book_slug TEXT NOT NULL,
              hadith_number INTEGER NOT NULL,
              narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
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
            INSERT INTO hadith_relations_v2(
              id, book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source, display_name_ur
            )
            SELECT id, book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source, display_name_ur
            FROM hadith_relations
            """
        )
        conn.execute("DROP TABLE hadith_relations")
        conn.execute("ALTER TABLE hadith_relations_v2 RENAME TO hadith_relations")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_hadith_rel_lookup ON hadith_relations(book_slug, hadith_number)"
        )
        print("Migrated hadith_relations unique key to include isnad_position")

    used_slugs = {r["slug"] for r in conn.execute("SELECT slug FROM narrators")}
    shared_ids = {"bukhari": BUKHARI_ID}
    for ur, sk in SHARED.items():
        if sk == "bukhari":
            continue
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
            (normalize_key(ur),),
        ).fetchone()
        if row:
            shared_ids[sk] = int(row["narrator_id"])

    packs = {}
    for num, chain in CHAINS.items():
        conn.execute(
            "DELETE FROM hadith_relations WHERE book_slug='bukhari' AND hadith_number=?", (num,)
        )
        pack_chain = []
        for pos, item in enumerate(chain, 1):
            nid = find_or_create(conn, item, used_slugs, shared_ids)
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
                    "name_ar": n["name_ar"] or "",
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
                    "absolute_hadiths": list(CHAINS.keys()),
                    "local_ilm": list(range(1, 77)),
                    "note": "User-final Urdu sanad by hadith number only; wording unchanged.",
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
            "policy": "User-final Urdu sanad by hadith number; wording preserved exactly.",
            "arabic_ibarat": arabic.get(num, ""),
            "chain": chain,
        }
        (PREVIEW_NARR / f"bukhari-{num}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    hdata = json.loads(gzip.decompress(PREVIEW_HADITH.read_bytes()))
    by_n = {h["n"]: h for h in hdata["hadiths"]}
    for num, chain in packs.items():
        h = by_n.get(num)
        if not h:
            continue
        primary = next(c for c in chain if c["role"] == "primary")
        h["ravi"] = primary["name_ur"]
        h["narrator"] = primary["name_en"] or primary["name_ur"]
        h["ravi_chain"] = [c["name_ur"] for c in chain]
        h["ravi_by_lang"] = {
            "ar": [c["name_ar"] or c["name_ur"] for c in chain],
            "en": [c["name_en"] or c["name_ur"] for c in chain],
            "ur": [c["name_ur"] for c in chain],
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
        "# Bukhari Kitab al-Ilm Hadith 1–76 Sanad Import (User Final)",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Knowledge N → absolute Bukhari (58+N).",
        "",
        "## Policy",
        "",
        "- Follow user hadith numbers only.",
        "- Preserve user Urdu wording exactly (no Arabic rematch / no rewording).",
        "",
        "## Chains",
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
    print(f"Imported {len(packs)} hadiths with exact user wording")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
