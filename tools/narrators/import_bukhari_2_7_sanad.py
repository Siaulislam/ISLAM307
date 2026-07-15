#!/usr/bin/env python3
"""Import Sahih Bukhari Hadith 2–7 sanad names from user-provided authenticated list.

POLICY:
  - Names and order from user research list (Bad' al-Wahy).
  - Cross-checked against authenticated Arabic text in hadith.db.
  - No biographies invented. Identity + isnad positions only.
  - Reuses existing narrator rows when aliases match (e.g. Bukhari, Aisha, Zuhri).
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
PREVIEW_HADITH = ROOT / "preview" / "library" / "data" / "hadith" / "bukhari.json.gz"
PREVIEW_NARR = ROOT / "preview" / "library" / "data" / "narrators"
CATALOG = PREVIEW_NARR / "catalog.json.gz"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_2_7_SANAD_IMPORT.md"
BATCH = "bukhari_2_7_sanad_import_2026-07-12"
BUKHARI_ID = 1

# User-provided chains (Urdu display). Position 1 is always Imam Bukhari (compiler).
CHAINS: dict[int, list[dict]] = {
    2: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن یوسف", "role": "in_isnad", "ar_frag": "عبد الله بن يوسف"},
        {"ur": "امام مالک بن انس", "role": "in_isnad", "ar_frag": "مالك"},
        {"ur": "ہشام بن عروہ", "role": "in_isnad", "ar_frag": "هشام بن عروة"},
        {"ur": "عروہ بن زبیر", "role": "in_isnad", "ar_frag": "عروة"},
        {"ur": "حضرت عائشہؓ", "role": "primary", "ar_frag": "عائشة", "en": "Aisha"},
    ],
    3: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "یحییٰ بن بکیر", "role": "in_isnad", "ar_frag": "يحيى بن بكير"},
        {"ur": "لیث بن سعد", "role": "in_isnad", "ar_frag": "الليث"},
        {"ur": "عقیل بن خالد", "role": "in_isnad", "ar_frag": "عقيل"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "ابن شهاب"},
        {"ur": "عروہ بن زبیر", "role": "in_isnad", "ar_frag": "عروة بن الزبير"},
        {"ur": "حضرت عائشہؓ", "role": "primary", "ar_frag": "عائشة", "en": "Aisha"},
    ],
    4: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "ابن شهاب"},
        {"ur": "ابو سلمہ بن عبدالرحمن", "role": "in_isnad", "ar_frag": "أبو سلمة بن عبد الرحمن"},
        {"ur": "حضرت جابر بن عبداللہ انصاریؓ", "role": "primary", "ar_frag": "جابر بن عبد الله", "en": "Jabir bin Abdullah Al-Ansari"},
    ],
    5: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "موسیٰ بن اسماعیل", "role": "in_isnad", "ar_frag": "موسى بن إسماعيل"},
        {"ur": "ابو عوانہ", "role": "in_isnad", "ar_frag": "أبو عوانة"},
        {"ur": "موسیٰ بن ابی عائشہ", "role": "in_isnad", "ar_frag": "موسى بن أبي عائشة"},
        {"ur": "سعید بن جبیر", "role": "in_isnad", "ar_frag": "سعيد بن جبير"},
        {"ur": "عبداللہ بن عباسؓ", "role": "primary", "ar_frag": "ابن عباس", "en": "Abdullah ibn Abbas"},
    ],
    6: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبدان", "role": "in_isnad", "ar_frag": "عبدان"},
        {"ur": "عبداللہ بن مبارک", "role": "in_isnad", "ar_frag": "عبد الله"},
        {"ur": "یونس بن یزید", "role": "in_isnad", "ar_frag": "يونس"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "الزهري"},
        {"ur": "عبیداللہ بن عبداللہ", "role": "in_isnad", "ar_frag": "عبيد الله بن عبد الله"},
        {"ur": "عبداللہ بن عباسؓ", "role": "primary", "ar_frag": "ابن عباس", "en": "Abdullah ibn Abbas"},
    ],
    7: [
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابو الیمان الحکم بن نافع", "role": "in_isnad", "ar_frag": "أبو اليمان الحكم بن نافع"},
        {"ur": "شعیب بن ابی حمزہ", "role": "in_isnad", "ar_frag": "شعيب"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "الزهري"},
        {"ur": "عبیداللہ بن عبداللہ بن عتبہ", "role": "in_isnad", "ar_frag": "عبيد الله بن عبد الله بن عتبة"},
        {"ur": "عبداللہ بن عباسؓ", "role": "primary", "ar_frag": "عبد الله بن عباس", "en": "Abdullah ibn Abbas"},
        {"ur": "ابو سفیان بن حربؓ", "role": "in_isnad", "ar_frag": "أبا سفيان بن حرب", "en": "Abu Sufyan ibn Harb"},
    ],
}

# Shared identity keys so the same person reuses one narrator id across hadiths.
SHARED_KEYS = {
    "امام بخاریؒ": "bukhari",
    "حضرت عائشہؓ": "aisha",
    "عروہ بن زبیر": "urwah-ibn-al-zubayr",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "عبداللہ بن عباسؓ": "abdullah-ibn-abbas",
    "عبیداللہ بن عبداللہ": "ubaydullah-ibn-abdullah",
    "عبیداللہ بن عبداللہ بن عتبہ": "ubaydullah-ibn-abdullah",  # same person, fuller nisbah
}


def strip_diac(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


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
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-") or "narrator"
    base = s[:80]
    candidate = base
    i = 2
    while candidate in used:
        candidate = f"{base}-{i}"
        i += 1
    used.add(candidate)
    return candidate


def open_gz(path: Path) -> tuple[sqlite3.Connection, Path]:
    raw = gzip.decompress(path.read_bytes())
    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.write(fd, raw)
    os.close(fd)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    return conn, Path(tmp)


def verify_arabic(conn_h: sqlite3.Connection) -> dict[int, list[str]]:
    missing: dict[int, list[str]] = {}
    for num, chain in CHAINS.items():
        row = conn_h.execute(
            """
            SELECT h.text_ar FROM hadiths h JOIN books b ON b.id=h.book_id
            WHERE b.slug='bukhari' AND h.hadith_number=?
            """,
            (num,),
        ).fetchone()
        ar = strip_diac(row["text_ar"] or "")
        miss = []
        for item in chain:
            frag = item.get("ar_frag")
            if not frag:
                continue
            if strip_diac(frag) not in ar:
                miss.append(frag)
        missing[num] = miss
    return missing


def find_or_create(conn: sqlite3.Connection, item: dict, used_slugs: set[str], shared: dict[str, int]) -> int:
    if item.get("narrator_id"):
        nid = int(item["narrator_id"])
        # refresh Urdu display alias for Bukhari
        ur = item["ur"]
        conn.execute("UPDATE narrators SET name_ur=? WHERE id=?", (ur, nid))
        nk = normalize_key(ur)
        if not conn.execute(
            "SELECT 1 FROM name_aliases WHERE narrator_id=? AND alias_normalized=?", (nid, nk)
        ).fetchone():
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (nid, "ur", ur, nk),
            )
        return nid

    ur = item["ur"]
    shared_key = SHARED_KEYS.get(ur)
    if shared_key and shared_key in shared:
        nid = shared[shared_key]
        conn.execute("UPDATE narrators SET name_ur=? WHERE id=?", (ur, nid))
        nk = normalize_key(ur)
        if not conn.execute(
            "SELECT 1 FROM name_aliases WHERE narrator_id=? AND alias_normalized=?", (nid, nk)
        ).fetchone():
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (nid, "ur", ur, nk),
            )
        return nid

    # alias match
    for alias in filter(None, [ur, item.get("en"), item.get("ar_frag")]):
        nk = normalize_key(alias)
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1", (nk,)
        ).fetchone()
        if row:
            nid = int(row["narrator_id"])
            conn.execute("UPDATE narrators SET name_ur=? WHERE id=?", (ur, nid))
            if shared_key:
                shared[shared_key] = nid
            ur_nk = normalize_key(ur)
            if not conn.execute(
                "SELECT 1 FROM name_aliases WHERE narrator_id=? AND alias_normalized=?", (nid, ur_nk)
            ).fetchone():
                conn.execute(
                    "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                    (nid, "ur", ur, ur_nk),
                )
            return nid

    next_id = (conn.execute("SELECT COALESCE(MAX(id),0) FROM narrators").fetchone()[0] or 0) + 1
    en = item.get("en") or ""
    ar = item.get("ar_frag") or ""
    slug = slugify(en or shared_key or ur, used_slugs)
    conn.execute(
        """
        INSERT INTO narrators(
          id, slug, name_ar, name_ur, name_en, full_name,
          kunyah, laqab, nasab, birth_text, death_text, birth_hijri, death_hijri,
          city, country, generation, is_companion, is_tabii, is_tab_tabii,
          timeline_notes, import_batch
        ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, NULL, ?)
        """,
        (next_id, slug, ar or None, ur, en or None, BATCH),
    )
    for lang, alias in (("ur", ur), ("en", en), ("ar", ar)):
        if not alias:
            continue
        nk = normalize_key(alias)
        try:
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (next_id, lang, alias, nk),
            )
        except sqlite3.IntegrityError:
            pass
    if shared_key:
        shared[shared_key] = next_id
    return next_id


def main() -> int:
    hconn, htmp = open_gz(HADITH_GZ)
    missing = verify_arabic(hconn)
    arabic_by_n = {}
    for n in CHAINS:
        arabic_by_n[n] = hconn.execute(
            """
            SELECT h.text_ar, h.narrator FROM hadiths h JOIN books b ON b.id=h.book_id
            WHERE b.slug='bukhari' AND h.hadith_number=?
            """,
            (n,),
        ).fetchone()
    hconn.close()
    htmp.unlink(missing_ok=True)

    for n, miss in missing.items():
        if miss:
            print(f"WARN hadith {n} missing fragments: {miss}")

    conn, tmp = open_gz(NARR_GZ)
    used_slugs = {r["slug"] for r in conn.execute("SELECT slug FROM narrators")}
    shared: dict[str, int] = {"bukhari": BUKHARI_ID}
    # seed shared from existing aliases if present
    for key, slug in {
        "aisha": "aisha",
        "urwah-ibn-al-zubayr": "urwah",
        "ibn-shihab-al-zuhri": "zuhri",
        "abdullah-ibn-abbas": "abbas",
    }.items():
        pass

    packs: dict[int, list[dict]] = {}
    created = 0
    reused = 0

    for num, chain in CHAINS.items():
        # clear previous scaffold relations for this hadith (keep nothing conflicting)
        conn.execute(
            "DELETE FROM hadith_relations WHERE book_slug='bukhari' AND hadith_number=?",
            (num,),
        )
        pack_chain = []
        for pos, item in enumerate(chain, start=1):
            before = conn.execute("SELECT COUNT(*) FROM narrators").fetchone()[0]
            nid = find_or_create(conn, item, used_slugs, shared)
            after = conn.execute("SELECT COUNT(*) FROM narrators").fetchone()[0]
            if after > before:
                created += 1
            else:
                reused += 1
            conn.execute(
                """
                INSERT INTO hadith_relations(book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source)
                VALUES ('bukhari', ?, ?, ?, ?, ?)
                """,
                (num, nid, item["role"], pos, BATCH),
            )
            n = dict(conn.execute("SELECT * FROM narrators WHERE id=?", (nid,)).fetchone())
            pack_chain.append(
                {
                    "order": pos,
                    "role": item["role"],
                    "narrator_id": nid,
                    "slug": n["slug"],
                    "name_ar": n["name_ar"] or item.get("ar_frag") or "",
                    "name_en": n["name_en"] or item.get("en") or "",
                    "name_ur": n["name_ur"] or item["ur"],
                    "full_name": n["full_name"] or "",
                    "kunyah": n["kunyah"] or "",
                    "laqab": n["laqab"] or "",
                    "nasab": n["nasab"] or "",
                    "birth_text": n["birth_text"] or "",
                    "death_text": n["death_text"] or "",
                    "generation": n["generation"] or "",
                    "is_companion": bool(n["is_companion"]),
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
                    "book": "bukhari",
                    "hadiths": list(CHAINS.keys()),
                    "created": created,
                    "reused": reused,
                    "arabic_missing_fragments": missing,
                },
                ensure_ascii=False,
            ),
        ),
    )
    conn.commit()

    # preview packs
    PREVIEW_NARR.mkdir(parents=True, exist_ok=True)
    for num, chain in packs.items():
        payload = {
            "book_slug": "bukhari",
            "hadith_number": num,
            "policy": "Sanad imported from authenticated research list; verified against Arabic ibarat. No AI biographies.",
            "arabic_ibarat": arabic_by_n[num]["text_ar"],
            "chain": chain,
        }
        (PREVIEW_NARR / f"bukhari-{num}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    # update hadith preview ravi fields
    hdata = json.loads(gzip.decompress(PREVIEW_HADITH.read_bytes()))
    by_n = {h["n"]: h for h in hdata["hadiths"]}
    for num, chain in packs.items():
        h = by_n.get(num)
        if not h:
            continue
        primary = next((c for c in chain if c["role"] == "primary"), chain[-1])
        h["ravi"] = primary["name_ur"]
        h["narrator"] = primary["name_en"] or primary["name_ur"]
        h["ravi_chain"] = [c["name_ar"] or c["name_ur"] for c in chain]
        h["ravi_by_lang"] = {
            "ar": [c["name_ar"] or c["name_ur"] for c in chain],
            "en": [c["name_en"] or c["name_ur"] for c in chain],
            "ur": [c["name_ur"] for c in chain],
        }
    with gzip.open(PREVIEW_HADITH, "wb", compresslevel=9) as gz:
        gz.write(json.dumps(hdata, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

    # refresh catalog names/aliases for touched narrators
    if CATALOG.exists():
        cat = json.loads(gzip.decompress(CATALOG.read_bytes()))
        for chain in packs.values():
            for c in chain:
                nid = str(c["narrator_id"])
                row = dict(conn.execute("SELECT * FROM narrators WHERE id=?", (c["narrator_id"],)).fetchone())
                cat.setdefault("narrators", {})[nid] = {
                    "id": row["id"],
                    "slug": row["slug"],
                    "name_ar": row["name_ar"],
                    "name_ur": row["name_ur"],
                    "name_en": row["name_en"],
                    "full_name": row["full_name"],
                    "kunyah": row["kunyah"],
                    "laqab": row["laqab"],
                    "nasab": row["nasab"],
                    "birth_text": row["birth_text"],
                    "death_text": row["death_text"],
                    "birth_hijri": row["birth_hijri"],
                    "death_hijri": row["death_hijri"],
                    "city": row["city"],
                    "country": row["country"],
                    "generation": row["generation"],
                    "is_companion": bool(row["is_companion"]),
                    "is_tabii": bool(row["is_tabii"]),
                    "is_tab_tabii": bool(row["is_tab_tabii"]),
                    "timeline_notes": row["timeline_notes"],
                    "import_batch": row["import_batch"],
                }
                cat.setdefault("aliases", {})[normalize_key(c["name_ur"])] = c["narrator_id"]
        for num, chain in packs.items():
            primary = next((c for c in chain if c["role"] == "primary"), chain[-1])
            cat.setdefault("primary_by_hadith", {})[f"bukhari:{num}"] = primary["narrator_id"]
        with gzip.open(CATALOG, "wb", compresslevel=9) as gz:
            gz.write(json.dumps(cat, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

    # update manifest
    man_path = ROOT / "preview" / "library" / "data" / "manifest.json"
    man = json.loads(man_path.read_text(encoding="utf-8"))
    narr = man.setdefault("narrators", {})
    for num, chain in packs.items():
        narr[f"bukhari-{num}"] = {"book": "bukhari", "hadith": num, "chain_length": len(chain)}
    man_path.write_text(json.dumps(man, ensure_ascii=False) + "\n", encoding="utf-8")

    conn.close()
    with gzip.open(NARR_GZ, "wb", compresslevel=9) as gz:
        gz.write(tmp.read_bytes())
    tmp.unlink(missing_ok=True)

    lines = [
        f"# Bukhari Hadith 2–7 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "## Policy",
        "",
        "- Names/order from authenticated research list provided by user.",
        "- Arabic fragments verified against `hadith.db`.",
        "- No AI biographies.",
        "",
        "## Arabic verification",
        "",
    ]
    for n, miss in missing.items():
        lines.append(f"- Hadith {n}: {'PASS' if not miss else 'MISSING ' + ', '.join(miss)}")
    lines.append("")
    for num, chain in packs.items():
        lines.append(f"### Hadith {num}")
        lines.append("")
        for c in chain:
            lines.append(f"{c['order']}. {c['name_ur']} (`{c['role']}`, id={c['narrator_id']})")
        lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"created={created} reused={reused}")
    print(f"Wrote {REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
