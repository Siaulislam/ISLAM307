#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Iman Hadith 1–10 (absolute nos. 8–17).

POLICY: user-provided Urdu sanad only; verify Arabic fragments; no AI bios.
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
MANIFEST = ROOT / "preview" / "library" / "data" / "manifest.json"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_IMAN_1_10_SANAD_IMPORT.md"
BATCH = "bukhari_iman_1_10_sanad_2026-07-12"
BUKHARI_ID = 1

# local_iman_number -> absolute bukhari number, chain (ur, role, ar_frag?)
# Absolute: Iman N = 7 + N
CHAINS: dict[int, list[dict]] = {
    8: [  # Iman 1
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبیداللہ بن موسیٰ", "role": "in_isnad", "ar_frag": "عبيد الله بن موسى"},
        {"ur": "حنظلہ بن ابی سفیان", "role": "in_isnad", "ar_frag": "حنظلة بن أبي سفيان"},
        {"ur": "عکرمہ بن خالد", "role": "in_isnad", "ar_frag": "عكرمة بن خالد"},
        {"ur": "عبداللہ بن عمرؓ", "role": "primary", "ar_frag": "ابن عمر", "en": "Abdullah ibn Umar"},
    ],
    9: [  # Iman 2
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن محمد", "role": "in_isnad", "ar_frag": "عبد الله بن محمد"},
        {"ur": "ابو عامر العقدی", "role": "in_isnad", "ar_frag": "أبو عامر العقدي"},
        {"ur": "سلیمان بن بلال", "role": "in_isnad", "ar_frag": "سليمان بن بلال"},
        {"ur": "عبداللہ بن دینار", "role": "in_isnad", "ar_frag": "عبد الله بن دينار"},
        {"ur": "ابو صالح", "role": "in_isnad", "ar_frag": "أبي صالح"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    10: [  # Iman 3
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "آدم بن ابی ایاس", "role": "in_isnad", "ar_frag": "آدم بن أبي إياس"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "عبداللہ بن ابی السفر", "role": "in_isnad", "ar_frag": "عبد الله بن أبي السفر"},
        {"ur": "اسماعیل", "role": "in_isnad", "ar_frag": "إسماعيل"},
        {"ur": "عامر شعبی", "role": "in_isnad", "ar_frag": "الشعبي"},
        {"ur": "عبداللہ بن عمروؓ", "role": "primary", "ar_frag": "عبد الله بن عمرو", "en": "Abdullah ibn Amr"},
    ],
    11: [  # Iman 4
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "سعید بن یحییٰ بن سعید القرشی", "role": "in_isnad", "ar_frag": "سعيد بن يحيى بن سعيد القرشي"},
        {"ur": "یحییٰ بن سعید", "role": "in_isnad", "ar_frag": "أبي قال"},
        {"ur": "ابو بردہ بن عبداللہ بن ابی بردہ", "role": "in_isnad", "ar_frag": "أبو بردة بن عبد الله بن أبي بردة"},
        {"ur": "ابو بردہ", "role": "in_isnad", "ar_frag": "أبي بردة"},
        {"ur": "ابو موسیٰ اشعریؓ", "role": "primary", "ar_frag": "أبي موسى", "en": "Abu Musa al-Ashari"},
    ],
    12: [  # Iman 5
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عمرو بن خالد", "role": "in_isnad", "ar_frag": "عمرو بن خالد"},
        {"ur": "لیث بن سعد", "role": "in_isnad", "ar_frag": "الليث"},
        {"ur": "یزید", "role": "in_isnad", "ar_frag": "يزيد"},
        {"ur": "ابوالخیر", "role": "in_isnad", "ar_frag": "أبي الخير"},
        {"ur": "عبداللہ بن عمروؓ", "role": "primary", "ar_frag": "عبد الله بن عمرو", "en": "Abdullah ibn Amr"},
    ],
    13: [  # Iman 6
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "مسدد", "role": "in_isnad", "ar_frag": "مسدد"},
        {"ur": "یحییٰ بن سعید", "role": "in_isnad", "ar_frag": "يحيى"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "قتادہ", "role": "in_isnad", "ar_frag": "قتادة"},
        {"ur": "انس بن مالکؓ", "role": "primary", "ar_frag": "أنس", "en": "Anas ibn Malik"},
    ],
    14: [  # Iman 7
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالیمان", "role": "in_isnad", "ar_frag": "أبو اليمان"},
        {"ur": "شعیب", "role": "in_isnad", "ar_frag": "شعيب"},
        {"ur": "ابوالزناد", "role": "in_isnad", "ar_frag": "أبو الزناد"},
        {"ur": "اعرج", "role": "in_isnad", "ar_frag": "الأعرج"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    15: [  # Iman 8
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "یعقوب بن ابراہیم", "role": "in_isnad", "ar_frag": "يعقوب بن إبراهيم"},
        {"ur": "ابن علیہ", "role": "in_isnad", "ar_frag": "ابن علية"},
        {"ur": "عبدالعزیز بن صہیب", "role": "in_isnad", "ar_frag": "عبد العزيز بن صهيب"},
        {"ur": "انس بن مالکؓ", "role": "primary", "ar_frag": "أنس", "en": "Anas ibn Malik"},
    ],
    16: [  # Iman 9
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "محمد بن المثنی", "role": "in_isnad", "ar_frag": "محمد بن المثنى"},
        {"ur": "عبدالوہاب الثقفی", "role": "in_isnad", "ar_frag": "عبد الوهاب الثقفي"},
        {"ur": "ایوب", "role": "in_isnad", "ar_frag": "أيوب"},
        {"ur": "ابو قلابہ", "role": "in_isnad", "ar_frag": "أبي قلابة"},
        {"ur": "انس بن مالکؓ", "role": "primary", "ar_frag": "أنس", "en": "Anas ibn Malik"},
    ],
    17: [  # Iman 10
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالولید", "role": "in_isnad", "ar_frag": "أبو الوليد"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "عبداللہ بن عبداللہ بن جبر", "role": "in_isnad", "ar_frag": "عبد الله بن عبد الله بن جبر"},
        {"ur": "انس بن مالکؓ", "role": "primary", "ar_frag": "أنس", "en": "Anas ibn Malik"},
    ],
}

SHARED = {
    "امام بخاریؒ": "bukhari",
    "شعبہ": "shu bah",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "عبداللہ بن عمروؓ": "abdullah-ibn-amr",
    "عبداللہ بن عمرؓ": "abdullah-ibn-umar",
    "ابوالیمان": "abu-al-yaman",
    "شعیب": "shuayb",
    "لیث بن سعد": "layth-ibn-saad",
    "یحییٰ بن سعید": "yahya-ibn-said",
}


def strip_diac(text: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


def normalize_key(raw: str) -> str:
    s = raw.strip().lower()
    s = s.replace("ʼ", "'").replace("`", "'").replace("´", "'")
    s = re.sub(r"[^\w\u0600-\u06ff\s-]", " ", s, flags=re.UNICODE)
    return re.sub(r"\s+", " ", s).strip()


def slugify(raw: str, used: set[str]) -> str:
    s = unicodedata.normalize("NFKD", raw)
    s = "".join(ch for ch in s if not unicodedata.combining(ch)).lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-") or "narrator"
    base = s[:80]
    cand = base
    i = 2
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


def find_or_create(conn, item, used_slugs, shared_ids):
    ur = item["ur"]
    if item.get("narrator_id"):
        nid = int(item["narrator_id"])
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

    sk = SHARED.get(ur)
    if sk and sk in shared_ids:
        nid = shared_ids[sk]
        # keep canonical name_ur on person; per-hadith override via display_name_ur
        return nid

    for alias in filter(None, [ur, item.get("en"), item.get("ar_frag")]):
        nk = normalize_key(alias)
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1", (nk,)
        ).fetchone()
        if row:
            nid = int(row["narrator_id"])
            if sk:
                shared_ids[sk] = nid
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
    slug = slugify(en or sk or ur, used_slugs)
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
        try:
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (next_id, lang, alias, normalize_key(alias)),
            )
        except sqlite3.IntegrityError:
            pass
    if sk:
        shared_ids[sk] = next_id
    return next_id


def main() -> int:
    hconn, htmp = open_gz(HADITH_GZ)
    arabic = {}
    missing = {}
    for num, chain in CHAINS.items():
        row = hconn.execute(
            """
            SELECT h.text_ar, h.narrator FROM hadiths h JOIN books b ON b.id=h.book_id
            WHERE b.slug='bukhari' AND h.hadith_number=?
            """,
            (num,),
        ).fetchone()
        arabic[num] = row["text_ar"]
        ar = strip_diac(row["text_ar"] or "")
        miss = []
        for item in chain:
            frag = item.get("ar_frag")
            if frag and strip_diac(frag) not in ar:
                # special case: يحيى via حدثنا أبي
                if frag == "حدثنا أبي" and "أبي" in ar:
                    continue
                if frag == "عن أبي بردة" and "أبي بردة" in ar:
                    continue
                miss.append(frag)
        missing[num] = miss
        print(f"abs {num}: missing={miss or 'PASS'}")
    hconn.close()
    htmp.unlink(missing_ok=True)

    conn, tmp = open_gz(NARR_GZ)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadith_relations)")}
    if "display_name_ur" not in cols:
        conn.execute("ALTER TABLE hadith_relations ADD COLUMN display_name_ur TEXT")

    used_slugs = {r["slug"] for r in conn.execute("SELECT slug FROM narrators")}
    shared_ids = {"bukhari": BUKHARI_ID}
    # seed known people from aliases
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
            "DELETE FROM hadith_relations WHERE book_slug='bukhari' AND hadith_number=?",
            (num,),
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
                    "name_ar": n["name_ar"] or item.get("ar_frag") or "",
                    "name_en": n["name_en"] or item.get("en") or "",
                    "name_ur": item["ur"],
                    "full_name": n["full_name"] or "",
                    "kunyah": n["kunyah"] or "",
                    "laqab": n["laqab"] or "",
                    "nasab": n["nasab"] or "",
                    "birth_text": n["birth_text"] or "",
                    "death_text": n["death_text"] or "",
                    "generation": n["generation"] or "",
                    "is_companion": bool(n["is_companion"]),
                    "kitab": "ایمان",
                    "kitab_local_number": num - 7,
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
                    "kitab": "Belief / ایمان",
                    "absolute_hadiths": list(CHAINS.keys()),
                    "local_iman": list(range(1, 11)),
                    "arabic_missing": missing,
                },
                ensure_ascii=False,
            ),
        ),
    )
    conn.commit()

    PREVIEW_NARR.mkdir(parents=True, exist_ok=True)
    for num, chain in packs.items():
        local = num - 7
        payload = {
            "book_slug": "bukhari",
            "kitab": "ایمان",
            "kitab_en": "Belief",
            "kitab_local_number": local,
            "hadith_number": num,
            "policy": "Sanad from authenticated research list; verified vs Arabic ibarat. No AI biographies.",
            "arabic_ibarat": arabic[num],
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
        h["ravi_chain"] = [c["name_ar"] or c["name_ur"] for c in chain]
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
                nid = str(c["narrator_id"])
                row = dict(conn.execute("SELECT * FROM narrators WHERE id=?", (c["narrator_id"],)).fetchone())
                cat.setdefault("narrators", {})[nid] = {
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
            "kitab": "Belief",
            "kitab_local": num - 7,
            "hadith": num,
            "chain_length": len(chain),
        }
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False) + "\n", encoding="utf-8")

    conn.close()
    with gzip.open(NARR_GZ, "wb", compresslevel=9) as gz:
        gz.write(tmp.read_bytes())
    tmp.unlink(missing_ok=True)

    lines = [
        "# Bukhari Kitab al-Iman Hadith 1–10 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Iman numbers map to absolute Bukhari numbers: **Iman N → absolute (7+N)**.",
        "",
        "## Arabic verification",
        "",
    ]
    for num, miss in missing.items():
        lines.append(f"- Absolute {num} (Iman {num-7}): {'PASS' if not miss else 'MISSING ' + ', '.join(miss)}")
    lines.append("")
    for num, chain in packs.items():
        lines.append(f"### Iman {num-7} / Absolute {num}")
        lines.append("")
        for c in chain:
            lines.append(f"{c['order']}. {c['name_ur']} (`{c['role']}`, id={c['narrator_id']})")
        lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
