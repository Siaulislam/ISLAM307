#!/usr/bin/env python3
"""Apply mandatory classical citation policy to narrators.db.gz.

- Adds edition/publisher columns on citation tables
- Adds field_citations table
- Registers Al-Kashif (Dhahabi) in approved sources
- Updates meta policy text
- Never invents volume/page/biography content

Usage:
  python3 tools/narrators/migrate_citation_policy.py
"""

from __future__ import annotations

import gzip
import json
import os
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NARR_GZ = ROOT / "app" / "assets" / "databases" / "narrators.db.gz"
SOURCES_JSON = ROOT / "app" / "assets" / "modules" / "narrators_sources.json"
REPORT = ROOT / "reports" / "verification" / "NARRATOR_CITATION_POLICY.md"
PREVIEW_CATALOG = ROOT / "preview" / "library" / "data" / "narrators" / "catalog.json.gz"

POLICY = (
    "Every classical narrator field must cite an approved Ahl al-Sunnah reference "
    "with Book Name, Author, Volume, and Page (Edition/Publisher when available). "
    "Never invent with AI. Never use Wikipedia, blogs, forums, or non-Sunni sources. "
    "If unverified, leave the field empty."
)

APPROVED_PRIMARY = [
    ("tahdhib-al-kamal", "Tahdhib al-Kamal fi Asma' al-Rijal", "Imam al-Mizzi"),
    ("tahdhib-al-tahdhib", "Tahdhib al-Tahdhib", "Hafiz Ibn Hajar al-Asqalani"),
    ("taqrib-al-tahdhib", "Taqrib al-Tahdhib", "Hafiz Ibn Hajar al-Asqalani"),
    ("al-jarh-wa-al-tadil", "Al-Jarh wa al-Ta'dil", "Imam Ibn Abi Hatim al-Razi"),
    ("siyar-alam-al-nubala", "Siyar A'lam al-Nubala'", "Imam al-Dhahabi"),
    ("tarikh-al-kabir", "Tarikh al-Kabir", "Imam al-Bukhari"),
    ("al-isabah", "Al-Isabah fi Tamyiz al-Sahabah", "Hafiz Ibn Hajar"),
    ("al-istiab", "Al-Isti'ab fi Ma'rifat al-Ashab", "Imam Ibn Abd al-Barr"),
    ("usd-al-ghabah", "Usd al-Ghabah fi Ma'rifat al-Sahabah", "Ibn al-Athir"),
    ("fath-al-bari", "Fath al-Bari", "Hafiz Ibn Hajar"),
    ("tabaqat-ibn-sad", "Tabaqat Ibn Sa'd", "Ibn Sa'd"),
    ("al-kashif", "Al-Kashif", "Imam al-Dhahabi"),
]


def add_column_if_missing(conn: sqlite3.Connection, table: str, column: str, decl: str) -> None:
    cols = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
    if column not in cols:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {decl}")


def main() -> int:
    raw = gzip.decompress(NARR_GZ.read_bytes())
    fd, tmp = tempfile.mkstemp(suffix=".db")
    os.write(fd, raw)
    os.close(fd)
    conn = sqlite3.connect(tmp)
    conn.row_factory = sqlite3.Row
    try:
        for table in ("sources", "teachers", "students", "reliability", "references_cite", "books_mentioned"):
            add_column_if_missing(conn, table, "edition", "TEXT")
            add_column_if_missing(conn, table, "publisher", "TEXT")

        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS field_citations (
              id INTEGER PRIMARY KEY,
              narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
              field_key TEXT NOT NULL,
              source_id INTEGER NOT NULL REFERENCES sources(id),
              volume TEXT,
              page TEXT,
              entry_number TEXT,
              edition TEXT,
              publisher TEXT,
              quote_ar TEXT,
              quote_en TEXT,
              quote_ur TEXT,
              notes TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_field_citations_narrator
              ON field_citations(narrator_id, field_key)
            """
        )

        # Register Al-Kashif
        exists = conn.execute("SELECT 1 FROM sources WHERE slug='al-kashif'").fetchone()
        if not exists:
            next_id = (conn.execute("SELECT COALESCE(MAX(id),0) FROM sources").fetchone()[0] or 0) + 1
            conn.execute(
                """
                INSERT INTO sources(
                  id, slug, name_ar, name_en, author_en, author_ar, sort_order,
                  license_status, attribution, notes, approved
                ) VALUES (?, 'al-kashif', 'الكاشف', 'Al-Kashif', 'Imam al-Dhahabi', 'الإمام الذهبي', ?,
                  'permission_required', ?, ?, 1)
                """,
                (
                    next_id,
                    next_id,
                    "Al-Kashif — Imam al-Dhahabi. Use only with license/permission.",
                    "Approved classical Sunni supporting reference. Text not bundled until licensed import.",
                ),
            )

        now = datetime.now(timezone.utc).isoformat()
        conn.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("schema_version", "1_rijal_citations"),
        )
        conn.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("policy", POLICY),
        )
        conn.execute(
            "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (
                "citation_rule",
                json.dumps(
                    {
                        "required": ["book_name", "author", "volume", "page"],
                        "optional": ["edition", "publisher"],
                        "approved_sources": [s[0] for s in APPROVED_PRIMARY],
                        "updated_at": now,
                    },
                    ensure_ascii=False,
                ),
            ),
        )
        conn.commit()

        sources = [dict(r) for r in conn.execute("SELECT id, slug, name_en, author_en FROM sources ORDER BY sort_order, id")]
        field_cite_count = conn.execute("SELECT COUNT(*) FROM field_citations").fetchone()[0]

        # Refresh preview catalog sources metadata only (no bio invention)
        if PREVIEW_CATALOG.exists():
            cat = json.loads(gzip.decompress(PREVIEW_CATALOG.read_bytes()))
            cat["citation_policy"] = POLICY
            cat["approved_sources"] = sources
            with gzip.open(PREVIEW_CATALOG, "wb", compresslevel=9) as gz:
                gz.write(json.dumps(cat, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))

        conn.close()
        with gzip.open(NARR_GZ, "wb", compresslevel=9) as gz:
            gz.write(Path(tmp).read_bytes())
    finally:
        Path(tmp).unlink(missing_ok=True)

    # Module JSON policy
    src = json.loads(SOURCES_JSON.read_text(encoding="utf-8"))
    src["schema_version"] = "1_rijal_citations"
    src["policy"] = [
        "Never generate narrator names, biographies, teachers, students, birth/death, or reliability with AI.",
        "Never scrape Wikipedia, blogs, forums, or unapproved websites.",
        "Use ONLY approved classical Ahl al-Sunnah wa al-Jama'ah references accepted by Hanafi/Deobandi scholars.",
        "Every classical field MUST include citation: Book Name, Author, Volume Number, Page Number (Edition/Publisher if available).",
        "If authentic information cannot be verified, leave the field empty — never guess.",
        "Never use Shia, Ahmadi/Qadiani, or other non-Sunni sources.",
        "Never assume classical data is unavailable. Never invent. Never merge opinions from different books.",
    ]
    src["citation_rule"] = {
        "required_fields": ["book_name", "author", "volume", "page"],
        "optional_fields": ["edition", "publisher"],
        "display_example": {
            "reliability": "Thiqah",
            "reference": ["Tahdhib al-Tahdhib", "Vol. 11", "Page 245"],
        },
    }
    existing = {s.get("slug") for s in src.get("approved_sources", [])}
    # Ensure Al-Kashif present; refresh primary list names
    if "al-kashif" not in existing:
        src.setdefault("approved_sources", []).append(
            {
                "slug": "al-kashif",
                "name_en": "Al-Kashif",
                "name_ar": "الكاشف",
                "author": "Imam al-Dhahabi",
                "license_status": "permission_required",
            }
        )
    src["forbidden"] = [
        "AI-generated biographies",
        "Wikipedia",
        "Blogs",
        "Forums",
        "User-generated content",
        "Unapproved websites",
        "Guessing or merging classical opinions",
        "Shia sources",
        "Ahmadi/Qadiani sources",
        "Hardcoding that classical biographies are unavailable",
        "Fields without Book/Author/Volume/Page citation",
    ]
    SOURCES_JSON.write_text(json.dumps(src, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Narrator Research & Citation Policy",
        "",
        f"Updated: `{now}`",
        "",
        "## Mandatory rule",
        "",
        POLICY,
        "",
        "## Approved primary references",
        "",
    ]
    for i, (slug, title, author) in enumerate(APPROVED_PRIMARY, 1):
        lines.append(f"{i}. **{title}** — {author} (`{slug}`)")
    lines.extend(
        [
            "",
            "## Citation storage",
            "",
            "- `field_citations` table: per-field Book / Author / Volume / Page / Edition / Publisher",
            "- `teachers`, `students`, `reliability`, `references_cite`, `books_mentioned`: each row cites a source with volume/page",
            "- Empty fields remain empty when unverified — accuracy over completeness",
            "",
            f"Current `field_citations` rows: **{field_cite_count}** (classical page-level imports pending).",
            "",
            "## Forbidden",
            "",
            "- Wikipedia, blogs, forums, AI-generated text",
            "- Unauthenticated websites",
            "- Shia, Ahmadi/Qadiani, or other non-Sunni sources",
            "- Guessing missing information",
            "",
        ]
    )
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Updated {NARR_GZ}")
    print(f"Wrote {REPORT}")
    print(f"field_citations={field_cite_count} sources={len(sources)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
