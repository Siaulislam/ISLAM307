#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Iman Hadith 11–20 (absolute nos. 18–27).

POLICY: user-provided Urdu sanad; Arabic-verified; no AI bios.
Note: Iman 18 transmitter corrected to الحرمي بن عمارة per Arabic ibarat
(user wrote عبادہ بن عباد).
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
REPORT = ROOT / "reports" / "verification" / "BUKHARI_IMAN_11_20_SANAD_IMPORT.md"
BATCH = "bukhari_iman_11_20_sanad_2026-07-12"
BUKHARI_ID = 1

CHAINS: dict[int, list[dict]] = {
    18: [  # Iman 11
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالیمان", "role": "in_isnad", "ar_frag": "أبو اليمان"},
        {"ur": "شعیب", "role": "in_isnad", "ar_frag": "شعيب"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "الزهري"},
        {"ur": "ابو ادریس عائذ اللہ بن عبداللہ", "role": "in_isnad", "ar_frag": "أبو إدريس"},
        {"ur": "عبادہ بن صامتؓ", "role": "primary", "ar_frag": "عبادة بن الصامت", "en": "Ubada ibn al-Samit"},
    ],
    19: [  # Iman 12
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن مسلمہ", "role": "in_isnad", "ar_frag": "عبد الله بن مسلمة"},
        {"ur": "امام مالک", "role": "in_isnad", "ar_frag": "مالك"},
        {"ur": "عبدالرحمن بن عبداللہ بن عبدالرحمن", "role": "in_isnad", "ar_frag": "عبد الرحمن بن عبد الله بن عبد الرحمن"},
        {
            "ur": "ابوہ",
            "role": "in_isnad",
            "ar_frag": "أبيه",
            "person_key": "abdullah-ibn-abdurrahman-abi-sasaa",
            "identity_ar": "عبد الله بن عبد الرحمن بن أبي صعصعة",
            "identity_ur": "عبداللہ بن عبدالرحمن بن ابی صعصعہ",
            "match": ["عبد الله بن عبد الرحمن بن أبي صعصعة"],
        },
        {"ur": "ابوسعید خدریؓ", "role": "primary", "ar_frag": "أبي سعيد الخدري", "en": "Abu Said al-Khudri"},
    ],
    20: [  # Iman 13
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "محمد بن سلام", "role": "in_isnad", "ar_frag": "محمد بن سلام"},
        {"ur": "عبدہ", "role": "in_isnad", "ar_frag": "عبدة"},
        {"ur": "ہشام بن عروہ", "role": "in_isnad", "ar_frag": "هشام"},
        {
            "ur": "عروہ",
            "role": "in_isnad",
            "ar_frag": "أبيه",
            "person_key": "urwah-ibn-al-zubayr",
            "match": ["عروہ بن زبیر", "عروة بن الزبير", "عروة"],
        },
        {"ur": "حضرت عائشہؓ", "role": "primary", "ar_frag": "عائشة", "en": "Aisha"},
    ],
    21: [  # Iman 14
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "سلیمان بن حرب", "role": "in_isnad", "ar_frag": "سليمان بن حرب"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "قتادہ", "role": "in_isnad", "ar_frag": "قتادة"},
        {"ur": "انس بن مالکؓ", "role": "primary", "ar_frag": "أنس", "en": "Anas ibn Malik"},
    ],
    22: [  # Iman 15
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "اسماعیل", "role": "in_isnad", "ar_frag": "إسماعيل"},
        {"ur": "امام مالک", "role": "in_isnad", "ar_frag": "مالك"},
        {"ur": "عمرو بن یحییٰ المازنی", "role": "in_isnad", "ar_frag": "عمرو بن يحيى المازني"},
        {
            "ur": "ابوہ",
            "role": "in_isnad",
            "ar_frag": "أبيه",
            "person_key": "yahya-al-mazini",
            "identity_ar": "يحيى المازني",
            "identity_ur": "یحییٰ المازنی",
            "match": ["يحيى المازني", "يحيى بن عمارة", "Yahya Al-Mazini"],
        },
        {"ur": "ابوسعید خدریؓ", "role": "primary", "ar_frag": "أبي سعيد الخدري", "en": "Abu Said al-Khudri"},
    ],
    23: [  # Iman 16
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "محمد بن عبیداللہ", "role": "in_isnad", "ar_frag": "محمد بن عبيد الله"},
        {"ur": "ابراہیم بن سعد", "role": "in_isnad", "ar_frag": "إبراهيم بن سعد"},
        {"ur": "صالح", "role": "in_isnad", "ar_frag": "صالح"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "ابن شهاب"},
        {"ur": "ابو امامہ بن سہل", "role": "in_isnad", "ar_frag": "أبي أمامة بن سهل"},
        {"ur": "ابوسعید خدریؓ", "role": "primary", "ar_frag": "أبا سعيد الخدري", "en": "Abu Said al-Khudri"},
    ],
    24: [  # Iman 17
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن یوسف", "role": "in_isnad", "ar_frag": "عبد الله بن يوسف"},
        {"ur": "امام مالک", "role": "in_isnad", "ar_frag": "مالك بن أنس"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "ابن شهاب"},
        {"ur": "سالم بن عبداللہ", "role": "in_isnad", "ar_frag": "سالم بن عبد الله"},
        {"ur": "عبداللہ بن عمرؓ", "role": "primary", "ar_frag": "أبيه", "en": "Abdullah ibn Umar"},
    ],
    25: [  # Iman 18 — Arabic: أبو روح الحرمي بن عمارة (not عبادہ بن عباد)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن محمد المسندی", "role": "in_isnad", "ar_frag": "عبد الله بن محمد المسندي"},
        {"ur": "ابوروح حرمی بن عمارہ", "role": "in_isnad", "ar_frag": "أبو روح الحرمي بن عمارة"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "واقد بن محمد", "role": "in_isnad", "ar_frag": "واقد بن محمد"},
        {
            "ur": "ابوہ",
            "role": "in_isnad",
            "ar_frag": "أبي",
            "person_key": "muhammad-ibn-zayd",
            "identity_ar": "محمد بن زيد",
            "identity_ur": "محمد بن زید",
            "match": ["محمد بن زيد", "Muhammad bin Zaid bin `Abdullah bin `Umar"],
        },
        {"ur": "عبداللہ بن عمرؓ", "role": "primary", "ar_frag": "ابن عمر", "en": "Abdullah ibn Umar"},
    ],
    26: [  # Iman 19 — parallel: Ahmad + Musa
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "احمد بن یونس", "role": "in_isnad", "ar_frag": "أحمد بن يونس"},
        {"ur": "موسیٰ بن اسماعیل", "role": "in_isnad", "ar_frag": "موسى بن إسماعيل"},
        {"ur": "ابراہیم بن سعد", "role": "in_isnad", "ar_frag": "إبراهيم بن سعد"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "ابن شهاب"},
        {"ur": "سعید بن مسیب", "role": "in_isnad", "ar_frag": "سعيد بن المسيب"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    27: [  # Iman 20
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالیمان", "role": "in_isnad", "ar_frag": "أبو اليمان"},
        {"ur": "شعیب", "role": "in_isnad", "ar_frag": "شعيب"},
        {"ur": "ابن شہاب الزہری", "role": "in_isnad", "ar_frag": "الزهري"},
        {"ur": "عامر بن سعد بن ابی وقاص", "role": "in_isnad", "ar_frag": "عامر بن سعد بن أبي وقاص"},
        {"ur": "سعد بن ابی وقاصؓ", "role": "primary", "ar_frag": "سعد", "en": "Sad ibn Abi Waqqas"},
    ],
}

SHARED = {
    "امام بخاریؒ": "bukhari",
    "شعبہ": "shu bah",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "عبداللہ بن عمرؓ": "abdullah-ibn-umar",
    "ابوالیمان": "abu-al-yaman",
    "شعیب": "shuayb",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "امام مالک": "malik-ibn-anas",
    "ابوسعید خدریؓ": "abu-said-al-khudri",
    "حضرت عائشہؓ": "aisha",
    "ہشام بن عروہ": "hisham-ibn-urwah",
    "قتادہ": "qatadah",
    "ابراہیم بن سعد": "ibrahim-ibn-sad",
    "عبداللہ بن یوسف": "abdullah-ibn-yusuf",
    "موسیٰ بن اسماعیل": "musa-ibn-ismail",
    "عروہ": "urwah-ibn-al-zubayr",
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

    # Prefer explicit identity aliases; never match on generic أبيه / ابوہ alone.
    candidates = []
    for alias in item.get("match") or []:
        candidates.append(alias)
    for alias in filter(None, [item.get("identity_ur"), item.get("identity_ar"), item.get("en")]):
        candidates.append(alias)
    if ur not in GENERIC_MATCH:
        candidates.append(ur)
    ar_frag = item.get("ar_frag")
    if ar_frag and ar_frag not in GENERIC_MATCH and strip_diac(ar_frag) not in {strip_diac(x) for x in GENERIC_MATCH}:
        candidates.append(ar_frag)

    for alias in candidates:
        nk = normalize_key(alias)
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1", (nk,)
        ).fetchone()
        if not row and alias:
            # also try exact alias text
            row = conn.execute(
                "SELECT narrator_id FROM name_aliases WHERE alias=? LIMIT 1", (alias,)
            ).fetchone()
        if row:
            nid = int(row["narrator_id"])
            if person_key:
                shared_ids[person_key] = nid
            # Keep display label as an extra alias on the resolved person (except generic ابوہ).
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
        miss = [item["ar_frag"] for item in chain if item.get("ar_frag") and strip_diac(item["ar_frag"]) not in ar]
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
    # Clean collapsed generic أبيه scaffold alias pollution from prior run.
    conn.execute(
        "DELETE FROM name_aliases WHERE narrator_id=6588 AND alias_normalized IN ('عروہ','ابوہ')"
    )
    for ur, sk in SHARED.items():
        if sk == "bukhari":
            continue
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
            (normalize_key(ur),),
        ).fetchone()
        if row:
            shared_ids[sk] = int(row["narrator_id"])
    # Prefer fuller Urwah identity for short display label عروہ.
    row = conn.execute(
        "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
        (normalize_key("عروہ بن زبیر"),),
    ).fetchone()
    if row:
        shared_ids["urwah-ibn-al-zubayr"] = int(row["narrator_id"])

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
                    "local_iman": list(range(11, 21)),
                    "arabic_missing": missing,
                    "note": "Iman 18: display name corrected to حرمی بن عمارہ per Arabic ibarat",
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
        "# Bukhari Kitab al-Iman Hadith 11–20 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Iman N → absolute Bukhari (7+N).",
        "",
        "## Note",
        "",
        "Iman 18: user wrote `ابوروح عبادہ بن عباد`; Arabic ibarat has `أبو روح الحرمي بن عمارة`.",
        "Stored display name: **ابوروح حرمی بن عمارہ**.",
        "",
        "Generic `ابوہ` / `أبيه` labels keep user display text but resolve to distinct father identities.",
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
