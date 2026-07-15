#!/usr/bin/env python3
"""
Build offline Quran Knowledge tables inside quran.db (Phase 4).

Sources (verbatim; do not alter annotations/text):
  - Quranic Arabic Corpus morphology v0.4 (GPL + terms) → http://corpus.quran.com
  - Quran.com API word glosses (EN/UR) with attribution → https://quran.com
  - Tanzil Uthmani ayah text already in quran.db (BY-ND) → https://tanzil.net

AI / explanations in the app must only use these local fields — never invent.
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import sqlite3
import time
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QURAN_DB = ROOT / "app" / "assets" / "databases" / "quran.db"
CACHE = Path(__file__).resolve().parent / "cache"
MORPH_GZ = CACHE / "quranic-corpus-morphology-0.4.txt.gz"
MORPH_TXT = CACHE / "quranic-corpus-morphology-0.4.txt"
SCHEMA = Path(__file__).resolve().parent / "schema_knowledge.sql"

# Buckwalter → Arabic (standard mapping used by QAC)
_BW = {
    "'": "ء",
    "|": "آ",
    ">": "أ",
    "&": "ؤ",
    "<": "إ",
    "}": "ئ",
    "A": "ا",
    "b": "ب",
    "p": "ة",
    "t": "ت",
    "v": "ث",
    "j": "ج",
    "H": "ح",
    "x": "خ",
    "d": "د",
    "*": "ذ",
    "r": "ر",
    "z": "ز",
    "s": "س",
    "$": "ش",
    "S": "ص",
    "D": "ض",
    "T": "ط",
    "Z": "ظ",
    "E": "ع",
    "g": "غ",
    "_": "ـ",
    "f": "ف",
    "q": "ق",
    "k": "ك",
    "l": "ل",
    "m": "م",
    "n": "ن",
    "h": "ه",
    "w": "و",
    "Y": "ى",
    "y": "ي",
    "F": "ً",
    "N": "ٌ",
    "K": "ٍ",
    "a": "َ",
    "u": "ُ",
    "i": "ِ",
    "~": "ّ",
    "o": "ْ",
    "^": "ٓ",
    "#": "ٔ",
    "`": "ٰ",
    "{": "ٱ",
    ":": "ۜ",
    "@": "۟",
    '"': "۠",
    "[": "ۢ",
    ";": "ۣ",
    ",": "ۥ",
    ".": "ۦ",
    "!": "ۨ",
    "-": "-",
    " ": " ",
}

_LOC = re.compile(r"^\((\d+):(\d+):(\d+):(\d+)\)$")
_POS = {
    "N": "Noun",
    "PN": "Proper noun",
    "ADJ": "Adjective",
    "V": "Verb",
    "P": "Preposition",
    "PRON": "Pronoun",
    "DEM": "Demonstrative",
    "REL": "Relative pronoun",
    "T": "Time adverb",
    "LOC": "Location adverb",
    "CONJ": "Conjunction",
    "DET": "Determiner",
    "NEG": "Negative particle",
    "INTG": "Interrogative",
    "VOC": "Vocative",
    "INL": "Quranic initials",
    "ACC": "Accusative particle",
    "AMD": "Amendment particle",
    "ANS": "Answer particle",
    "AVR": "Aversion particle",
    "CAUS": "Particle of cause",
    "CERT": "Particle of certainty",
    "CIRC": "Circumstantial particle",
    "COM": "Comitative particle",
    "COND": "Conditional particle",
    "EQ": "Equalization particle",
    "EXH": "Exhortation particle",
    "EXL": "Exception particle",
    "EXP": "Exceptive particle",
    "FUT": "Future particle",
    "INC": "Inceptive particle",
    "INT": "Particle of interpretation",
    "PREV": "Preventive particle",
    "PRO": "Prohibition particle",
    "REM": "Resumption particle",
    "RES": "Restriction particle",
    "RET": "Retraction particle",
    "RSLT": "Result particle",
    "SUP": "Supplemental particle",
    "SUR": "Surprise particle",
}


def bw_to_ar(text: str) -> str:
    return "".join(_BW.get(ch, ch) for ch in text or "")


def parse_features(feat: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in (feat or "").split("|"):
        if ":" in part:
            k, v = part.split(":", 1)
            out[k] = v
        elif part:
            out[part] = "1"
    return out


def grammar_summary(tag: str, feat: str) -> str:
    bits = [_POS.get(tag, tag)]
    f = parse_features(feat)
    if f.get("ROOT"):
        bits.append(f"root {bw_to_ar(f['ROOT'])}")
    if f.get("LEM"):
        bits.append(f"lemma {bw_to_ar(f['LEM'])}")
    for key in ("PERF", "IMPF", "IMPV", "PASS", "ACT", "PCPL", "VN"):
        if key in f:
            bits.append(key.lower())
    for key in ("1S", "1P", "2MS", "2FS", "2MP", "2FP", "3MS", "3FS", "3MP", "3FP", "MS", "FS", "MP", "FP", "M", "F"):
        if key in f:
            bits.append(key)
    for key in ("NOM", "ACC", "GEN"):
        if key in f:
            bits.append(key.lower())
    return " · ".join(bits)


def load_morphology(path: Path) -> dict[tuple[int, int, int], list[dict]]:
    if path.suffix == ".gz":
        raw = gzip.decompress(path.read_bytes()).decode("utf-8", "replace")
    else:
        raw = path.read_text(encoding="utf-8", errors="replace")

    words: dict[tuple[int, int, int], list[dict]] = defaultdict(list)
    for line in raw.splitlines():
        if not line or line.startswith("#") or line.startswith("LOCATION"):
            continue
        cols = line.split("\t")
        if len(cols) < 4:
            continue
        loc, form, tag, features = cols[0], cols[1], cols[2], cols[3]
        m = _LOC.match(loc.strip())
        if not m:
            continue
        s, a, w, p = map(int, m.groups())
        words[(s, a, w)].append(
            {
                "part": p,
                "form_bw": form,
                "tag": tag,
                "features": features,
                "form_ar": bw_to_ar(form),
            }
        )
    for key in words:
        words[key].sort(key=lambda x: x["part"])
    return words


def _fetch_json(url: str, cache_path: Path) -> dict:
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    req = urllib.request.Request(url, headers={"User-Agent": "ISLAM307/1.0 (offline Sadaqah Jariyah build)"})
    with urllib.request.urlopen(req, timeout=90) as resp:
        pack = json.loads(resp.read().decode("utf-8"))
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(pack, ensure_ascii=False), encoding="utf-8")
    return pack


def fetch_chapter_words(chapter: int) -> list[dict]:
    gloss_dir = CACHE / "wbw_glosses"
    en_pack = _fetch_json(
        (
            f"https://api.quran.com/api/v4/verses/by_chapter/{chapter}"
            f"?language=en&words=true&word_fields=text_uthmani,text_imlaei,translation,transliteration"
            f"&per_page=300"
        ),
        gloss_dir / f"en_{chapter:03d}.json",
    )
    ur_pack = _fetch_json(
        (
            f"https://api.quran.com/api/v4/verses/by_chapter/{chapter}"
            f"?language=ur&words=true&word_fields=text_uthmani,translation"
            f"&per_page=300"
        ),
        gloss_dir / f"ur_{chapter:03d}.json",
    )

    ur_map: dict[tuple[int, int], str] = {}
    for verse in ur_pack.get("verses", []):
        ayah = verse["verse_number"]
        for w in verse.get("words", []):
            if w.get("char_type_name") != "word":
                continue
            meaning = ((w.get("translation") or {}).get("text") or "").strip()
            ur_map[(ayah, w["position"])] = meaning

    rows = []
    for verse in en_pack.get("verses", []):
        ayah = verse["verse_number"]
        for w in verse.get("words", []):
            if w.get("char_type_name") != "word":
                continue
            pos = w["position"]
            rows.append(
                {
                    "surah": chapter,
                    "ayah": ayah,
                    "word_number": pos,
                    "text_ar": w.get("text_uthmani") or w.get("text") or "",
                    "text_imlaei": w.get("text_imlaei") or "",
                    "transliteration": ((w.get("transliteration") or {}).get("text") or "").strip(),
                    "meaning_en": ((w.get("translation") or {}).get("text") or "").strip(),
                    "meaning_ur": ur_map.get((ayah, pos), ""),
                }
            )
    return rows


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))
    conn.commit()


def rebuild_fts(conn: sqlite3.Connection) -> None:
    # External-content FTS5: drop/recreate is safer than DELETE+INSERT after bulk load.
    conn.execute("DROP TABLE IF EXISTS quran_words_fts")
    conn.execute(
        """
        CREATE VIRTUAL TABLE quran_words_fts USING fts5(
          text_ar,
          meaning_en,
          meaning_ur,
          transliteration,
          root,
          lemma,
          pos,
          morphology,
          content='quran_words',
          content_rowid='id'
        )
        """
    )
    conn.execute(
        """
        INSERT INTO quran_words_fts(
          rowid, text_ar, meaning_en, meaning_ur, transliteration, root, lemma, pos, morphology
        )
        SELECT id,
               text_ar,
               IFNULL(meaning_en,''),
               IFNULL(meaning_ur,''),
               IFNULL(transliteration,''),
               IFNULL(root,''),
               IFNULL(lemma,''),
               IFNULL(pos,''),
               IFNULL(morphology,'')
        FROM quran_words
        """
    )
    conn.commit()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=QURAN_DB)
    parser.add_argument("--chapters", type=str, default="1-114", help="e.g. 1-7 or 1,2,114")
    parser.add_argument("--skip-api", action="store_true", help="Morphology only (no EN/UR glosses)")
    args = parser.parse_args()

    morph_path = MORPH_GZ if MORPH_GZ.exists() else MORPH_TXT
    if not morph_path.exists():
        raise SystemExit(f"Missing QAC morphology file: {MORPH_GZ} or {MORPH_TXT}")
    if not args.db.exists():
        raise SystemExit(f"Missing quran.db at {args.db}")

    # Parse chapter range
    chapters: list[int] = []
    for part in args.chapters.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            chapters.extend(range(int(a), int(b) + 1))
        else:
            chapters.append(int(part))
    chapters = sorted(set(c for c in chapters if 1 <= c <= 114))

    print(f"Loading morphology from {morph_path.name}…")
    morph = load_morphology(morph_path)
    print(f"  morph words: {len(morph)}")

    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row
    ensure_schema(conn)
    conn.execute("DELETE FROM quran_word_parts")
    conn.execute("DELETE FROM quran_words")
    conn.commit()

    inserted = 0
    for chapter in chapters:
        if args.skip_api:
            gloss_rows = []
            # Build from morph only for this chapter
            keys = sorted(k for k in morph if k[0] == chapter)
            by_ayah: dict[int, list[int]] = defaultdict(list)
            for s, a, w in keys:
                by_ayah[a].append(w)
            for ayah, wnums in by_ayah.items():
                for wnum in sorted(set(wnums)):
                    parts = morph[(chapter, ayah, wnum)]
                    gloss_rows.append(
                        {
                            "surah": chapter,
                            "ayah": ayah,
                            "word_number": wnum,
                            "text_ar": "".join(p["form_ar"] for p in parts),
                            "text_imlaei": "",
                            "transliteration": " ".join(p["form_bw"] for p in parts),
                            "meaning_en": "",
                            "meaning_ur": "",
                        }
                    )
        else:
            print(f"Fetching word glosses chapter {chapter}…")
            gloss_rows = fetch_chapter_words(chapter)
            time.sleep(0.15)

        for g in gloss_rows:
            key = (g["surah"], g["ayah"], g["word_number"])
            parts = morph.get(key, [])
            stem = next((p for p in parts if "STEM" in p["features"] or p["tag"] not in {"DET", "P", "CONJ"}), parts[0] if parts else None)
            feat = stem["features"] if stem else ""
            parsed = parse_features(feat)
            root = bw_to_ar(parsed.get("ROOT", "")) if parsed.get("ROOT") else ""
            lemma = bw_to_ar(parsed.get("LEM", "")) if parsed.get("LEM") else ""
            pos = stem["tag"] if stem else ""
            morph_text = " | ".join(f"{p['tag']}:{p['features']}" for p in parts)
            grammar = grammar_summary(pos, feat) if stem else ""
            syntax = ""
            if "PREFIX" in feat:
                syntax = "Prefix segment"
            if "STEM" in feat:
                syntax = (syntax + " · " if syntax else "") + "Stem"
            if "SUFFIX" in feat:
                syntax = (syntax + " · " if syntax else "") + "Suffix"

            cur = conn.execute(
                """
                INSERT INTO quran_words(
                  surah, ayah, word_number, text_ar, text_imlaei, transliteration,
                  meaning_en, meaning_ur, root, lemma, pos, morphology,
                  grammar_summary, syntax_summary, occurrence_count, source
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?)
                """,
                (
                    g["surah"],
                    g["ayah"],
                    g["word_number"],
                    g["text_ar"] or ("".join(p["form_ar"] for p in parts)),
                    g.get("text_imlaei") or "",
                    g.get("transliteration") or "",
                    g.get("meaning_en") or "",
                    g.get("meaning_ur") or "",
                    root,
                    lemma,
                    pos,
                    morph_text,
                    grammar,
                    syntax,
                    "qac_morph_0.4+qurancom_wbw",
                ),
            )
            word_id = cur.lastrowid
            for p in parts:
                conn.execute(
                    """
                    INSERT INTO quran_word_parts(word_id, part_index, form_bw, tag, features)
                    VALUES (?,?,?,?,?)
                    """,
                    (word_id, p["part"], p["form_bw"], p["tag"], p["features"]),
                )
            inserted += 1
        conn.commit()
        print(f"  chapter {chapter}: {len(gloss_rows)} words")

    # Occurrence counts by root (and lemma / surface fallback)
    print("Computing occurrence counts…")
    conn.execute("UPDATE quran_words SET occurrence_count = 1")
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_count = (
          SELECT COUNT(*) FROM quran_words w2 WHERE w2.root = quran_words.root
        )
        WHERE root != ''
        """
    )
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_count = (
          SELECT COUNT(*) FROM quran_words w2 WHERE w2.lemma = quran_words.lemma
        )
        WHERE root = '' AND lemma != ''
        """
    )
    conn.execute(
        """
        UPDATE quran_words
        SET occurrence_count = (
          SELECT COUNT(*) FROM quran_words w2 WHERE w2.text_ar = quran_words.text_ar
        )
        WHERE root = '' AND lemma = ''
        """
    )
    conn.commit()
    rebuild_fts(conn)

    conn.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)",
        ("knowledge_schema", "1_words_qac"),
    )
    conn.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)",
        (
            "knowledge_sources",
            "Quranic Arabic Corpus morphology v0.4 (http://corpus.quran.com); Quran.com word glosses EN/UR; Tanzil Uthmani ayah text",
        ),
    )
    conn.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)",
        ("word_count", str(inserted)),
    )
    conn.execute(
        "INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)",
        ("schema_version", "3_knowledge"),
    )
    conn.commit()
    conn.close()
    print(f"Done. Inserted {inserted} words into {args.db}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
