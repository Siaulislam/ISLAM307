#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Iman Hadith 21–30 (absolute nos. 28–37).

POLICY: user-provided Urdu sanad; Arabic-verified; no AI bios.

Arabic overrides (local Iman → abs = 7+N):
- 22/29: primary frag ابن عباس (user عبداللہ بن عباسؓ display OK)
- 23/30: أبا ذر (not أبي ذر)
- 24/31: user chain is Bukhari Knowledge #95; abs 31 Arabic is
  عبد الرحمن بن المبارك → حماد بن زيد → أيوب/يونس → الحسن → الأحنف → أبو بكرة
- 25/32: keep بشر + سلیمان from Arabic (user omitted); محمد kept
- 26/33: أبو سهيل is kunyah of Nafi; next is أبيه (user wrote ابوعامر سہیل)
- 27/34: قبیصہ بن عقبہ (user wrote قتیبہ بن سعید)
- 29/36: حرمی بن حفص (user wrote حریز بن حفص)
- 30/37: user chain not in abs 37; Arabic is
  اسماعیل → مالک → ابن شہاب → حمید بن عبدالرحمن → ابوہریرہ
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
REPORT = ROOT / "reports" / "verification" / "BUKHARI_IMAN_21_30_SANAD_IMPORT.md"
BATCH = "bukhari_iman_21_30_sanad_2026-07-12"
BUKHARI_ID = 1

CHAINS: dict[int, list[dict]] = {
    28: [  # Iman 21
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "قتیبہ بن سعید", "role": "in_isnad", "ar_frag": "قتيبة"},
        {"ur": "لیث بن سعد", "role": "in_isnad", "ar_frag": "الليث"},
        {"ur": "یزید بن ابی حبیب", "role": "in_isnad", "ar_frag": "يزيد بن أبي حبيب"},
        {"ur": "ابوالخیر", "role": "in_isnad", "ar_frag": "أبي الخير"},
        {"ur": "عبداللہ بن عمروؓ", "role": "primary", "ar_frag": "عبد الله بن عمرو", "en": "Abdullah ibn Amr"},
    ],
    29: [  # Iman 22
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبداللہ بن مسلمہ", "role": "in_isnad", "ar_frag": "عبد الله بن مسلمة"},
        {"ur": "امام مالک", "role": "in_isnad", "ar_frag": "مالك"},
        {"ur": "زید بن اسلم", "role": "in_isnad", "ar_frag": "زيد بن أسلم"},
        {"ur": "عطاء بن یسار", "role": "in_isnad", "ar_frag": "عطاء بن يسار"},
        {"ur": "عبداللہ بن عباسؓ", "role": "primary", "ar_frag": "ابن عباس", "en": "Abdullah ibn Abbas"},
    ],
    30: [  # Iman 23
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "سلیمان بن حرب", "role": "in_isnad", "ar_frag": "سليمان بن حرب"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "واصل الاحدب", "role": "in_isnad", "ar_frag": "واصل الأحدب"},
        {"ur": "معرور بن سوید", "role": "in_isnad", "ar_frag": "المعرور"},
        {"ur": "ابوذر غفاریؓ", "role": "primary", "ar_frag": "أبا ذر", "en": "Abu Dharr"},
    ],
    31: [  # Iman 24 — Arabic abs 31 (user list matched Knowledge #95 instead)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "عبدالرحمن بن المبارک", "role": "in_isnad", "ar_frag": "عبد الرحمن بن المبارك"},
        {"ur": "حماد بن زید", "role": "in_isnad", "ar_frag": "حماد بن زيد"},
        {"ur": "ایوب", "role": "in_isnad", "ar_frag": "أيوب"},
        {"ur": "یونس", "role": "in_isnad", "ar_frag": "يونس"},
        {"ur": "حسن", "role": "in_isnad", "ar_frag": "الحسن"},
        {"ur": "احنف بن قیس", "role": "in_isnad", "ar_frag": "الأحنف بن قيس"},
        {"ur": "ابوبکرہؓ", "role": "primary", "ar_frag": "أبو بكرة", "en": "Abu Bakrah"},
    ],
    32: [  # Iman 25 — Arabic includes بشر + سلیمان
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالولید", "role": "in_isnad", "ar_frag": "أبو الوليد"},
        {"ur": "شعبہ", "role": "in_isnad", "ar_frag": "شعبة"},
        {"ur": "بشر", "role": "in_isnad", "ar_frag": "بشر"},
        {"ur": "محمد", "role": "in_isnad", "ar_frag": "محمد"},
        {"ur": "سلیمان", "role": "in_isnad", "ar_frag": "سليمان"},
        {"ur": "ابراہیم نخعی", "role": "in_isnad", "ar_frag": "إبراهيم"},
        {"ur": "علقمہ", "role": "in_isnad", "ar_frag": "علقمة"},
        {
            "ur": "عبداللہ بن مسعودؓ",
            "role": "primary",
            "ar_frag": "عبد الله",
            "en": "Abdullah ibn Masud",
            "person_key": "abdullah-ibn-masud",
            "match": ["عبداللہ بن مسعودؓ", "عبد الله بن مسعود", "Abdullah ibn Masud", "Ibn Masud"],
        },
    ],
    33: [  # Iman 26 — أبو سهيل = Nafi; then أبيه
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "سلیمان ابو الربیع", "role": "in_isnad", "ar_frag": "سليمان أبو الربيع"},
        {"ur": "اسماعیل بن جعفر", "role": "in_isnad", "ar_frag": "إسماعيل بن جعفر"},
        {
            "ur": "نافع بن مالک بن ابی عامر ابو سہیل",
            "role": "in_isnad",
            "ar_frag": "نافع بن مالك بن أبي عامر أبو سهيل",
            "person_key": "nafi-abu-suhail",
            "match": ["نافع بن مالك بن أبي عامر", "أبو سهيل"],
        },
        {
            "ur": "ابوہ",
            "role": "in_isnad",
            "ar_frag": "أبيه",
            "person_key": "malik-ibn-abi-amir",
            "identity_ar": "مالك بن أبي عامر",
            "identity_ur": "مالک بن ابی عامر",
            "match": ["مالك بن أبي عامر"],
        },
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    34: [  # Iman 27 — قبیصہ بن عقبہ (not قتیبہ)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "قبیصہ بن عقبہ", "role": "in_isnad", "ar_frag": "قبيصة بن عقبة"},
        {"ur": "سفیان الثوری", "role": "in_isnad", "ar_frag": "سفيان"},
        {"ur": "اعمش", "role": "in_isnad", "ar_frag": "الأعمش"},
        {"ur": "عبداللہ بن مرہ", "role": "in_isnad", "ar_frag": "عبد الله بن مرة"},
        {"ur": "مسروق", "role": "in_isnad", "ar_frag": "مسروق"},
        {"ur": "عبداللہ بن عمروؓ", "role": "primary", "ar_frag": "عبد الله بن عمرو", "en": "Abdullah ibn Amr"},
    ],
    35: [  # Iman 28
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "ابوالیمان", "role": "in_isnad", "ar_frag": "أبو اليمان"},
        {"ur": "شعیب", "role": "in_isnad", "ar_frag": "شعيب"},
        {"ur": "ابوالزناد", "role": "in_isnad", "ar_frag": "أبو الزناد"},
        {"ur": "اعرج", "role": "in_isnad", "ar_frag": "الأعرج"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
    36: [  # Iman 29 — حرمی بن حفص (not حریز)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "حرمی بن حفص", "role": "in_isnad", "ar_frag": "حرمي بن حفص"},
        {"ur": "عبدالواحد بن زیاد", "role": "in_isnad", "ar_frag": "عبد الواحد"},
        {"ur": "عمارہ بن قعقاع", "role": "in_isnad", "ar_frag": "عمارة"},
        {"ur": "ابوزرعہ بن عمرو بن جریر", "role": "in_isnad", "ar_frag": "أبو زرعة بن عمرو بن جرير"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبا هريرة", "en": "Abu Huraira"},
    ],
    37: [  # Iman 30 — Arabic abs 37 (user list does not match this hadith)
        {"ur": "امام بخاریؒ", "role": "compiler", "narrator_id": BUKHARI_ID},
        {"ur": "اسماعیل", "role": "in_isnad", "ar_frag": "إسماعيل"},
        {"ur": "امام مالک", "role": "in_isnad", "ar_frag": "مالك"},
        {"ur": "ابن شہاب", "role": "in_isnad", "ar_frag": "ابن شهاب", "person_key": "ibn-shihab-al-zuhri"},
        {"ur": "حمید بن عبدالرحمن", "role": "in_isnad", "ar_frag": "حميد بن عبد الرحمن"},
        {"ur": "ابوہریرہؓ", "role": "primary", "ar_frag": "أبي هريرة", "en": "Abu Huraira"},
    ],
}

SHARED = {
    "امام بخاریؒ": "bukhari",
    "شعبہ": "shu bah",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "عبداللہ بن عمرؓ": "abdullah-ibn-umar",
    "عبداللہ بن عمروؓ": "abdullah-ibn-amr",
    "عبداللہ بن عباسؓ": "abdullah-ibn-abbas",
    "ابوالیمان": "abu-al-yaman",
    "شعیب": "shuayb",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "ابن شہاب": "ibn-shihab-al-zuhri",
    "امام مالک": "malik-ibn-anas",
    "لیث بن سعد": "layth-ibn-sad",
    "ابوالخیر": "abu-al-khayr",
    "سلیمان بن حرب": "sulayman-ibn-harb",
    "عبداللہ بن مسلمہ": "abdullah-ibn-maslamah",
    "ابوالزناد": "abu-al-zinad",
    "اعرج": "al-araj",
    "قتیبہ بن سعید": "qutaybah-ibn-saeed",
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
    if ar_frag and ar_frag not in GENERIC_MATCH and strip_diac(ar_frag) not in {
        strip_diac(x) for x in GENERIC_MATCH
    }:
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
                    "local_iman": list(range(21, 31)),
                    "arabic_missing": missing,
                    "note": "Arabic overrides for Iman 24/26/27/29/30; see report",
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
        "# Bukhari Kitab al-Iman Hadith 21–30 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Iman N → absolute Bukhari (7+N).",
        "",
        "## Arabic overrides vs user list",
        "",
        "- **Iman 24 / abs 31:** user chain matches Knowledge hadith **95**, not Belief 31.",
        "  Stored Arabic chain ending with **ابوبکرہؓ**.",
        "- **Iman 25 / abs 32:** added **بشر** and **سلیمان** from Arabic parallel isnad.",
        "- **Iman 26 / abs 33:** `ابو سہیل` is kunyah of Nafi; next transmitter is **ابوہ** (not ابوعامر سہیل).",
        "- **Iman 27 / abs 34:** **قبیصہ بن عقبہ** (Arabic), not قتیبہ بن سعید.",
        "- **Iman 29 / abs 36:** **حرمی بن حفص** (Arabic), not حریز بن حفص.",
        "- **Iman 30 / abs 37:** user list not found on abs 37; stored Arabic",
        "  اسماعیل → مالک → ابن شہاب → حمید بن عبدالرحمن → ابوہریرہؓ.",
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
