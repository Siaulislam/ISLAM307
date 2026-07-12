#!/usr/bin/env python3
"""Import Sahih Bukhari Kitab al-Ilm (Knowledge) Hadith 1–76 (absolute nos. 59–134).

POLICY:
- Chains are Arabic-verified from authenticated Bukhari text (local DB / classical isnad).
- User Urdu sanad list applied only where local N (= abs 58+N) verifies against Arabic
  (locals 1–5). Remaining locals use Arabic-derived Urdu display names.
- No AI biographies.
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
CHAINS_JSON = ROOT / "data" / "narrators" / "imports" / "bukhari_ilm_1_76_chains.json"
PREVIEW_HADITH = ROOT / "preview" / "library" / "data" / "hadith" / "bukhari.json.gz"
PREVIEW_NARR = ROOT / "preview" / "library" / "data" / "narrators"
CATALOG = PREVIEW_NARR / "catalog.json.gz"
MANIFEST = ROOT / "preview" / "library" / "data" / "manifest.json"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_ILM_1_76_SANAD_IMPORT.md"
BATCH = "bukhari_ilm_1_76_sanad_2026-07-12"
BUKHARI_ID = 1

GENERIC_MATCH = {"أبيه", "أبي", "ابوه", "ابوہ", "ابيه", "أخيه", "اخيه", "أخي", "اخي"}

SHARED = {
    "امام بخاریؒ": "bukhari",
    "ابوہریرہؓ": "abu-huraira",
    "انس بن مالکؓ": "anas-ibn-malik",
    "عبداللہ بن عمرؓ": "abdullah-ibn-umar",
    "عبداللہ بن عمروؓ": "abdullah-ibn-amr",
    "عبداللہ بن عباسؓ": "abdullah-ibn-abbas",
    "عبداللہ بن مسعودؓ": "abdullah-ibn-masud",
    "عمر بن خطابؓ": "umar-ibn-al-khattab",
    "معاویہؓ": "muawiya",
    "علیؓ": "ali-ibn-abi-talib",
    "ام سلمہؓ": "umm-salama",
    "اسماء بنت ابی بکرؓ": "asma-bint-abi-bakr",
    "ابن شہاب": "ibn-shihab-al-zuhri",
    "ابن شہاب الزہری": "ibn-shihab-al-zuhri",
    "الزہری": "ibn-shihab-al-zuhri",
    "شعبہ": "shubah",
    "سفیان": "sufyan",
    "مسدد": "musaddad",
    "امام مالک": "malik-ibn-anas",
    "مالک": "malik-ibn-anas",
    "عروہ بن زبیر": "urwah-ibn-al-zubayr",
    "ابوالیمان": "abu-al-yaman",
    "ابو الیمان": "abu-al-yaman",
    "شعیب": "shuayb",
    "لیث": "layth-ibn-saad",
    "لیث بن سعد": "layth-ibn-saad",
    "قتیبہ": "qutaybah",
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


def polish_primary_ur(ur: str) -> str:
    u = re.sub(r"\s+", " ", (ur or "").strip())
    # normalize spaced عبداللہ forms
    u = u.replace("عبد اللہ", "عبداللہ").replace("عبید اللہ", "عبیداللہ")
    companions = {
        "عبداللہ بن عمرو": "عبداللہ بن عمروؓ",
        "عبداللہ بن عمر": "عبداللہ بن عمرؓ",
        "عبداللہ بن عباس": "عبداللہ بن عباسؓ",
        "عبداللہ بن مسعود": "عبداللہ بن مسعودؓ",
        "ابوہریرہ": "ابوہریرہؓ",
        "انس بن مالک": "انس بن مالکؓ",
        "انس": "انس بن مالکؓ",
        "عمر": "عمر بن خطابؓ",
        "معاویہ": "معاویہؓ",
        "علی": "علیؓ",
        "ام سلمہ": "ام سلمہؓ",
    }
    if u in companions:
        return companions[u]
    if not u.endswith("ؓ") and any(
        x in u for x in ("ہریرہ", "عباس", "مسعود", "مالک", "عمرو", "عمر", "عائشہ", "اسماء", "علی", "سلمہ")
    ):
        return u if u.endswith("ؓ") else u + "ؓ"
    return u


def load_chains() -> dict[int, list[dict]]:
    data = json.loads(CHAINS_JSON.read_text(encoding="utf-8"))
    chains: dict[int, list[dict]] = {}
    for row in data:
        absn = int(row["abs"])
        items = [
            {
                "ur": "امام بخاریؒ",
                "role": "compiler",
                "narrator_id": BUKHARI_ID,
            }
        ]
        for c in row["chain"]:
            item = {
                "ur": c["ur"],
                "role": c["role"],
                "ar_frag": c.get("ar_frag"),
            }
            for k in ("person_key", "identity_ar", "identity_ur", "match", "en", "skip_ar_frag_match"):
                if k in c:
                    item[k] = c[k]
            if item["role"] == "primary":
                item["ur"] = polish_primary_ur(item["ur"])
            items.append(item)
        chains[absn] = items
    return chains


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
    CHAINS = load_chains()
    meta_src = json.loads(CHAINS_JSON.read_text(encoding="utf-8"))
    user_applied = sorted({int(r["local"]) for r in meta_src if r.get("user_applied")})

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
        miss = []
        for item in chain:
            frag = item.get("ar_frag")
            if not frag or item.get("skip_ar_frag_match"):
                continue
            if frag in GENERIC_MATCH:
                continue
            sfrag = strip_diac(frag)
            if sfrag in ar:
                continue
            soft = sfrag[2:] if sfrag.startswith("ال") else sfrag
            if soft and soft in ar:
                continue
            tokens = [t for t in re.findall(r"\w+", sfrag) if len(t) > 2 and t not in ("بن", "ابن")]
            if tokens and sum(1 for t in tokens if t in ar) >= max(1, len(tokens) // 2):
                continue
            miss.append(frag)
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
        ("أبو هريرة", "abu-huraira"),
        ("انس بن مالکؓ", "anas-ibn-malik"),
        ("ابن شهاب", "ibn-shihab-al-zuhri"),
        ("الزهري", "ibn-shihab-al-zuhri"),
        ("عروة بن الزبير", "urwah-ibn-al-zubayr"),
        ("عروہ بن زبیر", "urwah-ibn-al-zubayr"),
        ("مالك", "malik-ibn-anas"),
        ("مسدد", "musaddad"),
        ("شعبة", "shu bah"),
        ("أبو اليمان", "abu-al-yaman"),
        ("شعيب", "shuayb"),
        ("الليث", "layth-ibn-saad"),
        ("قتيبة", "qutaybah"),
    ):
        row = conn.execute(
            "SELECT narrator_id FROM name_aliases WHERE alias_normalized=? LIMIT 1",
            (normalize_key(alias),),
        ).fetchone()
        if row:
            shared_ids[key] = int(row["narrator_id"])

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
                    "user_urdu_applied_locals": user_applied,
                    "arabic_missing": missing,
                    "note": (
                        "Knowledge chapter abs 59–134. User Urdu applied only for locals "
                        f"{user_applied}; others Arabic-derived due to numbering mismatch."
                    ),
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
            "policy": (
                "Sanad Arabic-verified from authenticated Bukhari text. "
                "User Urdu labels applied only where local numbering verifies."
            ),
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
        "# Bukhari Kitab al-Ilm (Knowledge) Hadith 1–76 Sanad Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "Local Knowledge N → absolute Bukhari (58+N). Range: abs **59–134**.",
        "",
        "## Policy",
        "",
        "- Arabic-verified from authenticated Bukhari `text_ar` / classical isnad.",
        "- User Urdu list (`bukhari_ilm_1_76_sanad_ur.txt`) applied only where local numbering verifies.",
        f"- User Urdu applied for locals: **{user_applied}**.",
        "- Remaining locals use Arabic-derived Urdu display names (user list numbering diverged from app abs 58+N).",
        "- No AI biographies.",
        "",
        "## Arabic verification",
        "",
    ]
    pass_n = sum(1 for m in missing.values() if not m)
    lines.append(f"PASS {pass_n} / {len(missing)}")
    lines.append("")
    for num, miss in missing.items():
        lines.append(
            f"- Absolute {num} (Ilm {num-58}): {'PASS' if not miss else 'MISSING ' + ', '.join(miss)}"
        )
    lines.append("")
    lines.append("## Chains")
    lines.append("")
    for num, chain in packs.items():
        flag = "user-urdu" if (num - 58) in user_applied else "arabic-derived-urdu"
        lines.append(f"### Ilm {num-58} / Absolute {num} ({flag})")
        lines.append("")
        for c in chain:
            lines.append(f"{c['order']}. {c['name_ur']} (`{c['role']}`, id={c['narrator_id']})")
        lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT}")
    print(f"Preview packs: {len(packs)} (bukhari-59 … bukhari-134)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
