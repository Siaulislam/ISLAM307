#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Iman Hadith 41–48 (absolute nos. 48–55).

POLICY: user-provided Urdu sanad; Arabic-verified; no AI bios.

Arabic overrides:
- 41/48: أبا وائل (not أبي وائل)
- 42/49: keep عبادہ بن صامت after أنس (Anas reports from Ubada)
- 43/50: أبو حيان التيمي
- 44/51: keep ابو سفیان after ابن عباس
- 46/53: أبي جمرة
- 48/55: أبي مسعود (user wrote عبداللہ بن مسعود — wrong companion)
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
REPORT = ROOT / "reports" / "verification" / "BUKHARI_IMAN_41_48_SANAD_IMPORT.md"
BATCH = "bukhari_iman_41_48_sanad_2026-07-12"
BUKHARI_ID = 1

CHAINS: dict[int, list[dict]] = {
    48: [  # Iman 41
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "محمد بن عرعرہ", "role": "in_isnad", "ar_frag": "محمد بن عرعرة"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "زبید", "role": "in_isnad", "ar_frag": "زبيد"},
        {"ur": "ابووائل", "role": "in_isnad", "ar_frag": "أبا وائل"},
        {
            "ur": "عبداللہ بن مسعودؓ",
            "role": "primary",
            "ar_frag": "عبد الله",
            "en": "Abdullah ibn Masud",
            "person_key": "abdullah-ibn-masud",
            "match": ["عبداللہ بن مسعودؓ", "عبد الله بن مسعود", "Abdullah ibn Masud"],
        },
    ],
    49: [  # Iman 42 — أنس عن عبادة
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "قتیبہ بن سعید", "role": "in_isnad", "ar_frag": "قتيبة بن سعيد"},
        {"ur": "اسماعیل بن جعفر", "role": "in_isnad", "ar_frag": "إسماعيل بن جعفر"},
        {"ur": "حمید", "role": "in_isnad", "ar_frag": "حميد"},
        {"ur": "انس بن مالکؓ", "role": "in_isnad", "ar_frag": "أنس", "person_key": "anas-ibn-malik"},
        {
            "ur": "عبادہ بن صامتؓ",
            "role": "primary",
            "ar_frag": "عبادة بن الصامت",
            "en": "Ubada ibn al-Samit",
            "person_key": "ubada-ibn-al-samit",
            "match": ["عبادہ بن صامتؓ", "عبادة بن الصامت"],
        },
    ],
    50: [  # Iman 43
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "مسدد", "role": "in_isnad", "ar_frag": "مسدد"},
        {"ur": "اسماعیل بن ابراہیم", "role": "in_isnad", "ar_frag": "إسماعيل بن إبراهيم"},
        {"ur": "ابو حیان التیمی", "role": "in_isnad", "ar_frag": "أبو حيان التيمي"},
        {"ur": "ابو زرعہ", "role": "in_isnad", "ar_frag": "أبي زرعة"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    51: [  # Iman 44 — includes ابو سفیان
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابراہیم بن حمزہ", "role": "in_isnad", "ar_frag": "إبراهيم بن حمزة"},
        {"ur": "ابراہیم بن سعد", "role": "in_isnad", "ar_frag": "إبراهيم بن سعد"},
        {"ur": "صالح", "role": "in_isnad", "ar_frag": "صالح"},
        {"ur": "ابن شہاب", "role": "in_isnad", "ar_frag": "ابن شهاب", "person_key": "ibn-shihab-al-zuhri"},
        {"ur": "عبیداللہ بن عبداللہ", "role": "in_isnad", "ar_frag": "عبيد الله بن عبد الله"},
        {
            "ur": "عبداللہ بن عباسؓ",
            "role": "in_isnad",
            "ar_frag": "عبد الله بن عباس",
            "person_key": "abdullah-ibn-abbas",
            "match": ["عبداللہ بن عباسؓ", "عبد الله بن عباس"],
        },
        {
            "ur": "ابو سفیان بن حربؓ",
            "role": "primary",
            "ar_frag": "أبو سفيان",
            "en": "Abu Sufyan ibn Harb",
            "person_key": "abu-sufyan",
            "match": ["ابو سفیان بن حربؓ", "أبو سفيان", "Abu Sufyan"],
        },
    ],
    52: [  # Iman 45
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابو نعیم", "role": "in_isnad", "ar_frag": "أبو نعيم"},
        {"ur": "زکریا", "role": "in_isnad", "ar_frag": "زكريا"},
        {"ur": "عامر", "role": "in_isnad", "ar_frag": "عامر"},
        {
            "ur": "نعمان بن بشیرؓ",
            "role": "primary",
            "ar_frag": "النعمان بن بشير",
            "en": "Al-Numan ibn Bashir",
        },
    ],
    53: [  # Iman 46
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "علی بن الجعد", "role": "in_isnad", "ar_frag": "علي بن الجعد"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "ابو جمرہ", "role": "in_isnad", "ar_frag": "أبي جمرة"},
        {
            "ur": "عبداللہ بن عباسؓ",
            "role": "primary",
            "ar_frag": "ابن عباس",
            "en": "Abdullah ibn Abbas",
            "person_key": "abdullah-ibn-abbas",
        },
    ],
    54: [  # Iman 47
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن مسلمہ", "role": "in_isnad", "ar_frag": "عبد الله بن مسلمة"},
        {"ur": "مالک", "role": "in_isnad", "ar_frag": "مالك", "person_key": "malik-ibn-anas"},
        {"ur": "یحییٰ بن سعید", "role": "in_isnad", "ar_frag": "يحيى بن سعيد"},
        {"ur": "محمد بن ابراہیم", "role": "in_isnad", "ar_frag": "محمد بن إبراهيم"},
        {"ur": "علقمہ بن وقاص", "role": "in_isnad", "ar_frag": "علقمة بن وقاص"},
        {
            "ur": "عمر بن خطابؓ",
            "role": "primary",
            "ar_frag": "عمر",
            "en": "Umar ibn al-Khattab",
            "person_key": "umar-ibn-al-khattab",
            "match": ["عمر بن خطابؓ", "عمر بن الخطاب", "Umar ibn al-Khattab"],
        },
    ],
    55: [  # Iman 48 — أبي مسعود (NOT ابن مسعود)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "حجاج بن منہال", "role": "in_isnad", "ar_frag": "حجاج بن منهال"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "عدی بن ثابت", "role": "in_isnad", "ar_frag": "عدي بن ثابت"},
        {"ur": "عبداللہ بن یزید", "role": "in_isnad", "ar_frag": "عبد الله بن يزيد"},
        {
            "ur": "ابو مسعودؓ",
            "role": "primary",
            "ar_frag": "أبي مسعود",
            "en": "Abu Masud",
            "person_key": "abu-masud",
            "match": ["أبي مسعود", "أبو مسعود", "ابو مسعودؓ", "Abu Masud"],
        },
    ],
}

SHARED = {
    "امام بخاریؒ": "bukhari",
    "شعبہ": "shu bah",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "امام مالک": "malik-ibn-anas",
    "مالک": "malik-ibn-anas",
    "مالک بن انس": "malik-ibn-anas",
    "عبداللہ بن عباسؓ": "abdullah-ibn-abbas",
    "عبداللہ بن مسعودؓ": "abdullah-ibn-masud",
    "عبادہ بن صامتؓ": "ubada-ibn-al-samit",
    "ابن شہاب": "ibn-shihab-al-zuhri",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "ابراہیم بن سعد": "ibrahim-ibn-sad",
    "قتیبہ بن سعید": "qutaybah-ibn-saeed",
    "عمر بن خطابؓ": "umar-ibn-al-khattab",
    "عبداللہ بن مسلمہ": "abdullah-ibn-maslamah",
}

GENERIC_MATCH = {"أبيه", "أبي", "ابوه", "ابوہ", "ابيه"}


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


def find_or_create(conn, item, used_slugs, shared_ids):
    ur = item["ur"]
    person_key = item.get("person_key") or SHARED.get(ur)
    ar_frag = item.get("ar_frag")

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

    candidates = []
    for alias in item.get("match") or []:
        candidates.append(alias)
    for alias in filter(None, [item.get("identity_ur"), item.get("identity_ar"), item.get("en")]):
        candidates.append(alias)
    if ur not in GENERIC_MATCH:
        candidates.append(ur)
    if (
        ar_frag
        and ar_frag not in GENERIC_MATCH
        and strip_diac(ar_frag) not in {strip_diac(x) for x in GENERIC_MATCH}
        and not item.get("skip_ar_frag_match")
    ):
        # Avoid collapsing distinct people via short shared Arabic tokens (هشام، محمد، يحيى).
        sfrag = strip_diac(ar_frag)
        if " " in sfrag or len(sfrag) >= 8:
            candidates.append(ar_frag)

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
            if ur not in GENERIC_MATCH:
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
    identity_ur = item.get("identity_ur") or (ur if ur not in GENERIC_MATCH else None)
    identity_ar = item.get("identity_ar") or (None if (ar_frag in GENERIC_MATCH) else ar_frag)
    en = item.get("en") or ""
    slug = slugify(en or person_key or identity_ar or identity_ur or ur, used_slugs)
    conn.execute(
        """
        INSERT INTO narrators(
          id, slug, name_ar, name_ur, name_en, full_name,
          kunyah, laqab, nasab, birth_text, death_text, birth_hijri, death_hijri,
          city, country, generation, is_companion, is_tabii, is_tab_tabii,
          timeline_notes, import_batch
        ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, NULL, ?)
        """,
        (next_id, slug, identity_ar, identity_ur, en or None, BATCH),
    )
    for lang, alias in (
        ("ur", identity_ur),
        ("ar", identity_ar),
        ("en", en),
        ("ur", ur if ur not in GENERIC_MATCH else None),
    ):
        if not alias:
            continue
        try:
            conn.execute(
                "INSERT INTO name_aliases(narrator_id, lang, alias, alias_normalized) VALUES (?,?,?,?)",
                (next_id, lang, alias, normalize_key(alias)),
            )
        except sqlite3.IntegrityError:
            pass
    if person_key:
        shared_ids[person_key] = next_id
    return next_id


def main() -> int:
    hconn, htmp = open_gz(HADITH_GZ)
    arabic, missing = {}, {}
    for num, chain in CHAINS.items():
        row = hconn.execute(
            """
            SELECT h.text_ar FROM hadiths h JOIN books b ON b.id=h.book_id
            WHERE b.slug='bukhari' AND h.hadith_number=?
            """,
            (num,),
        ).fetchone()
        arabic[num] = row["text_ar"]
        ar = strip_diac(row["text_ar"] or "")
        miss = [
            item["ar_frag"]
            for item in chain
            if item.get("ar_frag") and strip_diac(item["ar_frag"]) not in ar
        ]
        missing[num] = miss
        print(f"abs {num}: {'PASS' if not miss else miss}")
    hconn.close()
    htmp.unlink(missing_ok=True)

    conn, tmp = open_gz(NARR_GZ)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(hadith_relations)")}
    if "display_name_ur" not in cols:
        conn.execute("ALTER TABLE hadith_relations ADD COLUMN display_name_ur TEXT")

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
    for alias, key in (
        ("عروہ بن زبیر", "urwah-ibn-al-zubayr"),
        ("عبد الله بن مسعود", "abdullah-ibn-masud"),
        ("ابن مسعود", "abdullah-ibn-masud"),
    ):
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
            (normalize_key(alias),),
        ).fetchone()
        if row:
            shared_ids[key] = int(row["narrator_id"])

    packs = {}
    for num, chain in CHAINS.items():
        conn.execute("DELETE FROM hadith_relations WHERE book_slug='bukhari' AND hadith_number=?", (num,))
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
                    "local_iman": list(range(41, 49)),
                    "arabic_missing": missing,
                    "note": "Arabic overrides: عبادة(42), ابو سفیان(44), ابو مسعود not ابن مسعود(48)",
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
            "kitab": "ایمان",
            "kitab_en": "Belief",
            "kitab_local_number": num - 7,
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
        "# Bukhari Kitab al-Iman Hadith 41–48 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Iman N → absolute Bukhari (7+N).",
        "",
        "## Arabic overrides vs user list",
        "",
        "- **Iman 42 / abs 49:** kept **عبادہ بن صامتؓ** after أنس (Anas reports from him).",
        "- **Iman 44 / abs 51:** kept **ابو سفیان بن حربؓ** after ابن عباس.",
        "- **Iman 48 / abs 55:** Arabic is **أبي مسعود**, not عبداللہ بن مسعود → stored **ابو مسعودؓ**.",
        "",
        "## Arabic verification",
        "",
    ]
    for num, miss in missing.items():
        lines.append(
            f"- Absolute {num} (Iman {num-7}): {'PASS' if not miss else 'MISSING ' + ', '.join(miss)}"
        )
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
