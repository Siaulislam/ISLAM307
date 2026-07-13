#!/usr/bin/env python3
"""Import Sahih Bukhari Hadith 1 sanad narrators from authenticated Ibarat + research file.

POLICY:
  - Never invent names/biographies with AI.
  - Chain order verified against authenticated Arabic text in hadith.db.
  - Arabic display names cross-checked with sunnah.com narrator titles (IDs stored).
  - Biographical fields imported only from the provided classical-research file
    (cites Taqrib, Tahdhib, Siyar, etc. — approved source catalog).
  - Prophet ﷺ included in sanad order mapping as role=prophet (not as jarh subject).

Usage:
  python3 tools/narrators/import_bukhari_1_from_ibarat.py
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = Path(__file__).with_name("schema.sql")
BUILD = Path(__file__).with_name("build_narrators_db.py")
IBARAT = ROOT / "data" / "narrators" / "imports" / "bukhari_1_sanad_urdu.txt"
HADITH_GZ = ROOT / "app" / "assets" / "databases" / "hadith.db.gz"
OUT_DB = ROOT / "app" / "assets" / "databases" / "narrators.db"
OUT_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"
REPORT = ROOT / "reports" / "verification" / "BUKHARI_1_SANAD_IMPORT.md"
PREVIEW_JSON = ROOT / "preview" / "library" / "data" / "narrators" / "bukhari-1.json"
SOURCES_JSON = ROOT / "app" / "assets" / "modules" / "narrators_sources.json"

BATCH = "bukhari_1_ibarat_import_2026-07-12"

# Arabic forms as they appear in authenticated hadith.db text_ar (diacritics stripped for name_ar short form).
# Verified against: حَدَّثَنَا الْحُمَيْدِيُّ عَبْدُ اللَّهِ بْنُ الزُّبَيْرِ ... سُفْيَانُ ... يَحْيَى بْنُ سَعِيدٍ الْأَنْصَارِيُّ ...
EXPECTED_AR_FRAGMENTS = [
    "الحميدي",
    "عبد الله بن الزبير",
    "سفيان",
    "يحيى بن سعيد",
    "محمد بن إبراهيم التيمي",
    "علقمة بن وقاص",
    "عمر بن الخطاب",
    "رسول الله",
]

# sunnah.com narrator IDs for isnad transmitters (not compiler / Prophet)
SUNNAH_IDS = {
    2: 4698,  # الحميدي
    3: 3443,  # سفيان بن عيينة
    4: 8272,  # يحيى بن سعيد الأنصاري
    5: 6796,  # محمد بن إبراهيم
    6: 5719,  # علقمة بن وقاص
    7: 5913,  # عمر بن الخطاب
}

SOURCE_NAME_MAP = {
    "تقریب التہذیب": 3,
    "تقريب التهذيب": 3,
    "تہذیب التہذیب": 2,
    "تهذيب التهذيب": 2,
    "تہذیب الکمال": 1,
    "تهذيب الكمال": 1,
    "سیر أعلام النبلاء": 4,
    "سير أعلام النبلاء": 4,
    "طبقات ابن سعد": 8,
    "الجرح والتعدیل": 10,
    "الجرح والتعديل": 10,
    "التاریخ الکبیر": 9,
    "التاريخ الكبير": 9,
    "الإصابة": 5,
}


def strip_diac(text: str) -> str:
    return re.sub(r"[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]", "", text or "")


def fold_ur_to_arish(text: str) -> str:
    """Normalize Urdu orthography toward Arabic letter forms for name_ar storage."""
    t = text or ""
    t = t.replace("ی", "ي").replace("ے", "ي").replace("ہ", "ه").replace("ک", "ك")
    t = t.replace("آ", "آ").replace("أ", "أ")
    return t.strip()


def parse_sections(text: str) -> dict[int, str]:
    chunks = re.split(r"\nراوی نمبر\s*(\d+)\s*\n", text)
    sections: dict[int, str] = {}
    i = 1
    while i < len(chunks) - 1:
        num = int(chunks[i])
        body = chunks[i + 1]
        if num not in sections or len(body) > len(sections[num]):
            sections[num] = body
        i += 2
    return sections


def field(body: str, label: str) -> str:
    m = re.search(
        rf"(?:^|\n){re.escape(label)}\s*\n+(.+?)(?=\n\n(?:پورا نام|نام مبارک|کنیت|لقب|القابات|نسب|پیدائش|ولادت|وفات|وصال|عمر|طبقہ|مشہور نام|مقام وفات|مدفن|بعثت|ہجرت|علمی مقام|علمی و دینی مقام|ثقاہت|استعمال شدہ مراجع|معتبر مراجع|اہم |فضائل|تصانیف|خصوصیات|اگلے|حدیث|بسم |━)|\Z)",
        body,
        re.S,
    )
    if not m:
        return ""
    val = m.group(1).strip()
    # Single-line fields: take first line only when label is short identity field
    if label in {"کنیت", "لقب", "مشہور نام"}:
        val = val.split("\n", 1)[0].strip()
    return re.sub(r"\s+", " ", val).strip()


def parse_refs(body: str) -> list[int]:
    m = re.search(r"استعمال شدہ مراجع\s*\n+(.*?)(?=\n━|\nحدیث|\nاگلے|\Z)", body, re.S)
    if not m:
        return []
    ids: list[int] = []
    for line in m.group(1).splitlines():
        line = re.sub(r"^\d+[\.۔)]\s*", "", line.strip())
        if not line:
            continue
        for key, sid in SOURCE_NAME_MAP.items():
            if key in line:
                if sid not in ids:
                    ids.append(sid)
                break
    return ids


def parse_list_block(body: str, heading: str) -> list[str]:
    m = re.search(
        rf"(?:^|\n){re.escape(heading)}\s*\n+(.*?)(?=\n\n(?:اہم |تصانیف|ثقاہت|فضائل|استعمال|علمی|━)|\Z)",
        body,
        re.S,
    )
    if not m:
        return []
    out: list[str] = []
    for line in m.group(1).splitlines():
        line = re.sub(r"^\d+[\.۔)]\s*", "", line.strip())
        line = line.lstrip("•●✔- ").strip()
        if line and len(line) < 120:
            out.append(line)
    return out


def verify_arabic_isnad(text_ar: str) -> list[str]:
    plain = strip_diac(text_ar)
    missing = [f for f in EXPECTED_AR_FRAGMENTS if f not in plain]
    return missing


# Curated records: Arabic/English identity from isnad + sunnah; bio fields from Ibarat file.
# isnad_position: 1 = compiler Bukhari … 7 = companion … 8 = Prophet ﷺ
NARRATORS = [
    {
        "order": 1,
        "role": "compiler",
        "slug": "muhammad-ibn-ismail-al-bukhari",
        "name_ar": "محمد بن إسماعيل البخاري",
        "name_en": "Muhammad ibn Ismail al-Bukhari",
        "name_ur_title_key": "امام محمد بن اسماعیل البخاری",
        "in_arabic_isnad": False,  # compiler, not inside matn isnad string
    },
    {
        "order": 2,
        "role": "in_isnad",
        "slug": "abdullah-ibn-al-zubayr-al-humaydi",
        "name_ar": "الحميدي عبد الله بن الزبير",
        "name_en": "Abdullah ibn al-Zubayr al-Humaydi",
        "name_ur_title_key": "امام الحمیدی عبداللہ بن الزبیر",
        "ar_fragment": "الحميدي",
        "sunnah_id": 4698,
    },
    {
        "order": 3,
        "role": "in_isnad",
        "slug": "sufyan-ibn-uyaynah",
        "name_ar": "سفيان بن عيينة",
        "name_en": "Sufyan ibn Uyaynah",
        "name_ur_title_key": "امام سفیان بن عیینہ",
        "ar_fragment": "سفيان",
        "sunnah_id": 3443,
    },
    {
        "order": 4,
        "role": "in_isnad",
        "slug": "yahya-ibn-said-al-ansari",
        "name_ar": "يحيى بن سعيد الأنصاري",
        "name_en": "Yahya ibn Sa'id al-Ansari",
        "name_ur_title_key": "امام یحییٰ بن سعید الانصاری",
        "ar_fragment": "يحيى بن سعيد",
        "sunnah_id": 8272,
    },
    {
        "order": 5,
        "role": "in_isnad",
        "slug": "muhammad-ibn-ibrahim-al-taymi",
        "name_ar": "محمد بن إبراهيم التيمي",
        "name_en": "Muhammad ibn Ibrahim al-Taymi",
        "name_ur_title_key": "امام محمد بن ابراہیم",
        "ar_fragment": "محمد بن إبراهيم التيمي",
        "sunnah_id": 6796,
    },
    {
        "order": 6,
        "role": "in_isnad",
        "slug": "alqamah-ibn-waqqas-al-laythi",
        "name_ar": "علقمة بن وقاص الليثي",
        "name_en": "Alqamah ibn Waqqas al-Laythi",
        "name_ur_title_key": "امام علقمہ بن وقاص اللیثی",
        "ar_fragment": "علقمة بن وقاص",
        "sunnah_id": 5719,
    },
    {
        "order": 7,
        "role": "primary",
        "slug": "umar-ibn-al-khattab",
        "name_ar": "عمر بن الخطاب",
        "name_en": "Umar ibn al-Khattab",
        "name_ur_title_key": "سیدنا عمر بن الخطاب",
        "ar_fragment": "عمر بن الخطاب",
        "sunnah_id": 5913,
        "is_companion": 1,
    },
    {
        "order": 8,
        "role": "prophet",
        "slug": "prophet-muhammad",
        "name_ar": "رسول الله ﷺ",
        "name_en": "The Messenger of Allah ﷺ",
        "name_ur_title_key": "رسول اللہ",
        "ar_fragment": "رسول الله",
        "is_companion": 0,
    },
]


def ensure_base_db(conn: sqlite3.Connection) -> None:
    """Ensure schema + approved sources exist (reuse build seed if empty)."""
    n = conn.execute("SELECT COUNT(*) FROM sources").fetchone()[0]
    if n == 0:
        # bootstrap via build script logic
        sys.path.insert(0, str(Path(__file__).parent))
        import build_narrators_db as b

        for row in b.APPROVED_SOURCES:
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
                    f"{row[3]} — {row[4]}.",
                    "Approved classical Sunni reference.",
                ),
            )


def main() -> int:
    if not IBARAT.exists():
        raise SystemExit(f"Missing Ibarat import file: {IBARAT}")
    if not HADITH_GZ.exists():
        raise SystemExit(f"Missing {HADITH_GZ}")

    # Verify Arabic isnad from authenticated hadith.db
    tmp = ROOT / "app" / "assets" / "databases" / "_hadith_tmp_check.db"
    tmp.write_bytes(gzip.decompress(HADITH_GZ.read_bytes()))
    hconn = sqlite3.connect(tmp)
    hconn.row_factory = sqlite3.Row
    row = hconn.execute(
        """
        SELECT h.text_ar, h.narrator FROM hadiths h
        JOIN books b ON b.id = h.book_id
        WHERE b.slug='bukhari' AND h.hadith_number=1
        """
    ).fetchone()
    hconn.close()
    tmp.unlink(missing_ok=True)
    if not row or not (row["text_ar"] or "").strip():
        raise SystemExit("Bukhari 1 Arabic missing in authenticated hadith.db")
    text_ar = row["text_ar"]
    missing_frags = verify_arabic_isnad(text_ar)
    if missing_frags:
        raise SystemExit(f"Arabic isnad verification failed; missing fragments: {missing_frags}")

    sections = parse_sections(IBARAT.read_text(encoding="utf-8"))
    if set(sections) != set(range(1, 9)):
        raise SystemExit(f"Expected ravi sections 1..8, got {sorted(sections)}")

    # Start from existing gz or fresh schema
    if OUT_GZ.exists():
        OUT_DB.write_bytes(gzip.decompress(OUT_GZ.read_bytes()))
    else:
        OUT_DB.unlink(missing_ok=True)
        conn0 = sqlite3.connect(OUT_DB)
        conn0.executescript(SCHEMA.read_text(encoding="utf-8"))
        conn0.commit()
        conn0.close()

    conn = sqlite3.connect(OUT_DB)
    conn.row_factory = sqlite3.Row
    ensure_base_db(conn)

    # Clear previous batch for this hadith mapping (idempotent re-import)
    conn.execute(
        "DELETE FROM hadith_relations WHERE book_slug=? AND hadith_number=? AND mapping_source=?",
        ("bukhari", 1, BATCH),
    )

    preview_chain: list[dict] = []
    imported_ids: list[int] = []

    for spec in NARRATORS:
        order = spec["order"]
        body = sections[order]
        title = body.strip().split("\n")[0].strip()
        full = field(body, "پورا نام") or field(body, "نام مبارک") or title
        kunyah = field(body, "کنیت")
        # Strip parenthetical uncertainty notes from kunyah (keep name only)
        if kunyah and "بعض" in kunyah:
            kunyah = re.split(r"\s*\(", kunyah, 1)[0].strip()
        laqab = field(body, "لقب") or field(body, "القابات")
        if laqab and "●" in laqab:
            # keep concise list of titles
            titles = [t.strip(" ●") for t in re.split(r"[●\n]+", laqab) if t.strip(" ●")]
            laqab = " · ".join(titles[:6])
        nasab = field(body, "نسب")
        birth = field(body, "پیدائش") or field(body, "ولادت")
        death = field(body, "وفات") or field(body, "وصال")
        if not death:
            death = field(body, "مقام وفات")
        madfan = field(body, "مدفن")
        if madfan and death and madfan not in death:
            death = f"{death} — مدفن: {madfan}"
        generation = field(body, "طبقہ")
        mashhur = field(body, "مشہور نام")
        if spec["role"] == "prophet" and not generation:
            generation = "النبي ﷺ"

        # Verify fragment in Arabic isnad when expected
        frag = spec.get("ar_fragment")
        if frag and frag not in strip_diac(text_ar):
            raise SystemExit(f"Order {order}: Arabic fragment {frag!r} not found in authenticated isnad")

        # Upsert narrator by slug
        existing = conn.execute("SELECT id FROM narrators WHERE slug=?", (spec["slug"],)).fetchone()
        is_companion = int(spec.get("is_companion") or 0)
        is_tabii = 1 if generation and "تابعین" in generation and "اتباع" not in generation[:3] and "صحابی" not in generation else 0
        if "اواسط تابعین" in (generation or "") or "صغار تابعین" in (generation or "") or "کبار تابعین" in (generation or ""):
            is_tabii = 1
        is_tab_tabii = 1 if generation and "اتباع تابعین" in generation else 0
        if spec["role"] == "prophet":
            is_companion = 0
            is_tabii = 0
            is_tab_tabii = 0
            generation = generation or "النبي ﷺ"

        # Extract hijri years roughly
        birth_hijri = ""
        death_hijri = ""
        m = re.search(r"(\d{2,4})\s*ھ", birth or "")
        if m:
            birth_hijri = m.group(1)
        m = re.search(r"(\d{2,4})\s*ھ", death or "")
        if m:
            death_hijri = m.group(1)

        city = ""
        country = ""
        if "بخارا" in (birth or ""):
            city, country = "Bukhara", "Uzbekistan"
        if "مکہ" in (death or "") or "مكة" in (death or ""):
            city = city or "Makkah"
            country = country or "Saudi Arabia"
        if "مدینہ" in (death or "") or "مدينه" in (death or ""):
            city = "Madinah"
            country = "Saudi Arabia"

        vals = {
            "slug": spec["slug"],
            "name_ar": spec["name_ar"],
            "name_ur": title,
            "name_en": spec["name_en"],
            "full_name": full,
            "kunyah": kunyah,
            "laqab": laqab or mashhur,
            "nasab": nasab,
            "birth_text": birth,
            "death_text": death,
            "birth_hijri": birth_hijri,
            "death_hijri": death_hijri,
            "city": city,
            "country": country,
            "generation": generation,
            "is_companion": is_companion,
            "is_tabii": is_tabii,
            "is_tab_tabii": is_tab_tabii,
            "timeline_notes": f"Sanad order {order} for Sahih Bukhari Hadith 1. Import batch {BATCH}.",
            "import_batch": BATCH,
        }

        if existing:
            nid = int(existing["id"])
            conn.execute(
                """
                UPDATE narrators SET
                  name_ar=?, name_ur=?, name_en=?, full_name=?, kunyah=?, laqab=?, nasab=?,
                  birth_text=?, death_text=?, birth_hijri=?, death_hijri=?, city=?, country=?,
                  generation=?, is_companion=?, is_tabii=?, is_tab_tabii=?, timeline_notes=?, import_batch=?
                WHERE id=?
                """,
                (
                    vals["name_ar"],
                    vals["name_ur"],
                    vals["name_en"],
                    vals["full_name"],
                    vals["kunyah"],
                    vals["laqab"],
                    vals["nasab"],
                    vals["birth_text"],
                    vals["death_text"],
                    vals["birth_hijri"],
                    vals["death_hijri"],
                    vals["city"],
                    vals["country"],
                    vals["generation"],
                    vals["is_companion"],
                    vals["is_tabii"],
                    vals["is_tab_tabii"],
                    vals["timeline_notes"],
                    vals["import_batch"],
                    nid,
                ),
            )
            # clear dependent rows for re-import
            for table in ("name_aliases", "teachers", "students", "reliability", "references_cite", "books_mentioned"):
                conn.execute(f"DELETE FROM {table} WHERE narrator_id=?", (nid,))
        else:
            cur = conn.execute(
                """
                INSERT INTO narrators(
                  slug, name_ar, name_ur, name_en, full_name, kunyah, laqab, nasab,
                  birth_text, death_text, birth_hijri, death_hijri, city, country,
                  generation, is_companion, is_tabii, is_tab_tabii, timeline_notes, import_batch
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    vals["slug"],
                    vals["name_ar"],
                    vals["name_ur"],
                    vals["name_en"],
                    vals["full_name"],
                    vals["kunyah"],
                    vals["laqab"],
                    vals["nasab"],
                    vals["birth_text"],
                    vals["death_text"],
                    vals["birth_hijri"],
                    vals["death_hijri"],
                    vals["city"],
                    vals["country"],
                    vals["generation"],
                    vals["is_companion"],
                    vals["is_tabii"],
                    vals["is_tab_tabii"],
                    vals["timeline_notes"],
                    vals["import_batch"],
                ),
            )
            nid = int(cur.lastrowid)

        imported_ids.append(nid)

        # Aliases
        aliases = [
            ("ar", vals["name_ar"]),
            ("en", vals["name_en"]),
            ("ur", vals["name_ur"]),
            ("ur", full),
        ]
        if mashhur:
            aliases.append(("ur", mashhur))
            aliases.append(("ar", fold_ur_to_arish(mashhur)))
        if kunyah:
            aliases.append(("ur", kunyah))
        sid = spec.get("sunnah_id")
        if sid:
            aliases.append(("en", f"sunnah:{sid}"))
            aliases.append(("ar", f"sunnah.com/narrator/{sid}"))

        def norm_key(s: str) -> str:
            s = s.strip().lower()
            s = re.sub(r"[ʼ'`´]", "'", s)
            s = re.sub(r"[^\w\u0600-\u06ff\s-]", " ", s)
            return re.sub(r"\s+", " ", s).strip()

        seen_a: set[str] = set()
        for lang, alias in aliases:
            alias = (alias or "").strip()
            if not alias:
                continue
            key = f"{lang}:{norm_key(alias)}"
            if key in seen_a:
                continue
            seen_a.add(key)
            conn.execute(
                """
                INSERT OR IGNORE INTO name_aliases(narrator_id, lang, alias, alias_normalized)
                VALUES (?,?,?,?)
                """,
                (nid, lang, alias, norm_key(alias)),
            )

        # References / books mentioned from file (approved sources only)
        for source_id in parse_refs(body):
            conn.execute(
                """
                INSERT INTO books_mentioned(narrator_id, source_id, notes)
                VALUES (?,?,?)
                """,
                (nid, source_id, f"Listed in Ibarat research file for Bukhari 1 sanad order {order}"),
            )
            conn.execute(
                """
                INSERT INTO references_cite(narrator_id, source_id, field_key, text_ur, notes)
                VALUES (?,?,?,?,?)
                """,
                (
                    nid,
                    source_id,
                    "general",
                    f"Cited for sanad narrator #{order} of Sahih Bukhari Hadith 1",
                    BATCH,
                ),
            )

        if sid:
            # store sunnah mapping as cite note under Taqrib catalog (identity cross-check)
            conn.execute(
                """
                INSERT INTO references_cite(narrator_id, source_id, field_key, entry_number, text_en, notes)
                VALUES (?,?,?,?,?,?)
                """,
                (
                    nid,
                    3,
                    "sunnah_com_id",
                    str(sid),
                    f"https://sunnah.com/narrator/{sid}",
                    "Cross-checked Arabic isnad name against sunnah.com narrator page for Bukhari 1",
                ),
            )

        # Teachers / students (names only as listed in file — cite first approved source used)
        ref_ids = parse_refs(body) or [3]
        primary_source = ref_ids[0]
        if spec["role"] != "prophet":
            for tname in parse_list_block(body, "اہم اساتذہ")[:12]:
                conn.execute(
                    """
                    INSERT INTO teachers(narrator_id, teacher_name_en, teacher_name_ar, source_id, notes)
                    VALUES (?,?,?,?,?)
                    """,
                    (nid, tname, fold_ur_to_arish(tname), primary_source, "From Ibarat research file list"),
                )
            for sname in parse_list_block(body, "اہم شاگرد")[:12]:
                conn.execute(
                    """
                    INSERT INTO students(narrator_id, student_name_en, student_name_ar, source_id, notes)
                    VALUES (?,?,?,?,?)
                    """,
                    (nid, sname, fold_ur_to_arish(sname), primary_source, "From Ibarat research file list"),
                )

        # Reliability bullets
        for ruling in parse_list_block(body, "ثقاہت")[:10]:
            conn.execute(
                """
                INSERT INTO reliability(narrator_id, source_id, ruling_ur, notes)
                VALUES (?,?,?,?)
                """,
                (nid, primary_source, ruling, BATCH),
            )

        # Hadith relation
        role = spec["role"]
        if role == "primary":
            role_db = "primary"
        elif role == "prophet":
            role_db = "prophet"
        elif role == "compiler":
            role_db = "compiler"
        else:
            role_db = "in_isnad"
        conn.execute(
            """
            INSERT INTO hadith_relations(book_slug, hadith_number, narrator_id, role, isnad_position, mapping_source)
            VALUES (?,?,?,?,?,?)
            """,
            ("bukhari", 1, nid, role_db, order, BATCH),
        )

        preview_chain.append(
            {
                "order": order,
                "role": role_db,
                "narrator_id": nid,
                "slug": spec["slug"],
                "name_ar": vals["name_ar"],
                "name_en": vals["name_en"],
                "name_ur": vals["name_ur"],
                "full_name": vals["full_name"],
                "kunyah": vals["kunyah"],
                "laqab": vals["laqab"],
                "nasab": vals["nasab"],
                "birth_text": vals["birth_text"],
                "death_text": vals["death_text"],
                "generation": vals["generation"],
                "sunnah_com_id": sid,
                "sunnah_com_url": f"https://sunnah.com/narrator/{sid}" if sid else None,
                "is_companion": bool(is_companion),
            }
        )
        print(f"Imported #{order} id={nid} {spec['name_en']}")

    # meta
    count = conn.execute("SELECT COUNT(*) FROM narrators").fetchone()[0]
    maps = conn.execute("SELECT COUNT(*) FROM hadith_relations").fetchone()[0]
    conn.execute("INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)", ("biography_rows", str(count)))
    conn.execute("INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)", ("hadith_mappings", str(maps)))
    conn.execute(
        "INSERT OR REPLACE INTO meta(key,value) VALUES (?,?)",
        (
            "last_import",
            json.dumps(
                {
                    "batch": BATCH,
                    "at": datetime.now(timezone.utc).isoformat(),
                    "book": "bukhari",
                    "hadith": 1,
                    "narrators": len(NARRATORS),
                    "arabic_verified": True,
                    "missing_fragments": missing_frags,
                },
                ensure_ascii=False,
            ),
        ),
    )
    conn.commit()
    conn.close()

    with gzip.open(OUT_GZ, "wb", compresslevel=9) as gz:
        gz.write(OUT_DB.read_bytes())
    OUT_DB.unlink(missing_ok=True)

    # Preview pack
    PREVIEW_JSON.parent.mkdir(parents=True, exist_ok=True)
    preview_doc = {
        "book_slug": "bukhari",
        "hadith_number": 1,
        "policy": "Imported from Arabic isnad verification + classical research file. Never AI-invented.",
        "arabic_ibarat": text_ar,
        "chain": preview_chain,
        "batch": BATCH,
    }
    PREVIEW_JSON.write_text(json.dumps(preview_doc, ensure_ascii=False, indent=2), encoding="utf-8")

    # Update sources catalog pack flags
    if SOURCES_JSON.exists():
        data = json.loads(SOURCES_JSON.read_text(encoding="utf-8"))
        data.setdefault("pack", {})
        data["pack"]["has_biography_rows"] = True
        data["pack"]["has_hadith_mappings"] = True
        data["pack"]["notes"] = (
            "Includes Bukhari Hadith 1 sanad import (8 narrators) verified against Arabic isnad. "
            "Additional biographies require further licensed imports."
        )
        data["pack"]["last_import_batch"] = BATCH
        SOURCES_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Bukhari Hadith 1 — Sanad Narrator Import",
        "",
        f"Batch: `{BATCH}`",
        "",
        "## Verification",
        "",
        "- Authenticated Arabic isnad from `hadith.db` checked for all expected name fragments: **PASS**",
        "- sunnah.com narrator IDs attached for transmitters #2–#7",
        "- Biographical fields from provided Ibarat research file (cites Taqrib / Tahdhib / Siyar / etc.)",
        "- Prophet ﷺ stored as `role=prophet`, order 8",
        "- Primary companion mapping: **Umar ibn al-Khattab** (`role=primary`, order 7)",
        "",
        "## Sanad order",
        "",
        "| Order | Role | Arabic | English | Kunyah | Sunnah ID |",
        "|------:|------|--------|---------|--------|----------:|",
    ]
    for c in preview_chain:
        lines.append(
            f"| {c['order']} | {c['role']} | {c['name_ar']} | {c['name_en']} | "
            f"{c.get('kunyah') or '—'} | {c.get('sunnah_com_id') or '—'} |"
        )
    lines += [
        "",
        "## Artifacts",
        "",
        "- `app/assets/databases/narrators.db.gz`",
        "- `preview/library/data/narrators/bukhari-1.json`",
        "- Source file: `data/narrators/imports/bukhari_1_sanad_urdu.txt`",
        "",
    ]
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_GZ}")
    print(f"Wrote {PREVIEW_JSON}")
    print(f"Wrote {REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
