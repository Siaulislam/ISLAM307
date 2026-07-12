-- ISLAM 307 — Narrator (Rijāl) Knowledge System
-- Authenticated classical Sunni sources ONLY.
-- NEVER invent biographies, names, teachers, students, dates, or reliability with AI.
-- Populate only from licensed/authorized imports of approved reference works.

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Approved classical reference works (catalog). Biographies cite these only.
CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_ar TEXT,
  name_en TEXT NOT NULL,
  author_en TEXT,
  author_ar TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  license_status TEXT NOT NULL DEFAULT 'permission_required',
  -- permission_required | licensed | public_domain | unavailable
  attribution TEXT,
  notes TEXT,
  approved INTEGER NOT NULL DEFAULT 1 CHECK (approved IN (0, 1))
);

CREATE TABLE IF NOT EXISTS narrators (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_ar TEXT,
  name_ur TEXT,
  name_en TEXT,
  full_name TEXT,
  kunyah TEXT,
  laqab TEXT,
  nasab TEXT,
  birth_text TEXT,
  death_text TEXT,
  birth_hijri TEXT,
  death_hijri TEXT,
  city TEXT,
  country TEXT,
  -- companion | tabii | tab_tabii | later | unknown — ONLY from approved sources
  generation TEXT,
  is_companion INTEGER NOT NULL DEFAULT 0 CHECK (is_companion IN (0, 1)),
  is_tabii INTEGER NOT NULL DEFAULT 0 CHECK (is_tabii IN (0, 1)),
  is_tab_tabii INTEGER NOT NULL DEFAULT 0 CHECK (is_tab_tabii IN (0, 1)),
  timeline_notes TEXT,
  -- Import provenance (never AI)
  import_batch TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS name_aliases (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  lang TEXT NOT NULL, -- ar | en | ur | other
  alias TEXT NOT NULL,
  alias_normalized TEXT NOT NULL,
  UNIQUE (narrator_id, lang, alias_normalized)
);

CREATE INDEX IF NOT EXISTS idx_aliases_norm ON name_aliases(alias_normalized);
CREATE INDEX IF NOT EXISTS idx_aliases_lang_norm ON name_aliases(lang, alias_normalized);

-- Teachers / students: each edge must cite an approved source opinion (never merge).
CREATE TABLE IF NOT EXISTS teachers (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  teacher_narrator_id INTEGER REFERENCES narrators(id),
  teacher_name_ar TEXT,
  teacher_name_en TEXT,
  source_id INTEGER NOT NULL REFERENCES sources(id),
  volume TEXT,
  page TEXT,
  entry_number TEXT,
  quote_ar TEXT,
  quote_en TEXT,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS students (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  student_narrator_id INTEGER REFERENCES narrators(id),
  student_name_ar TEXT,
  student_name_en TEXT,
  source_id INTEGER NOT NULL REFERENCES sources(id),
  volume TEXT,
  page TEXT,
  entry_number TEXT,
  quote_ar TEXT,
  quote_en TEXT,
  notes TEXT
);

-- Jarḥ wa taʿdīl / reliability — one row per source opinion (never merge).
CREATE TABLE IF NOT EXISTS reliability (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  source_id INTEGER NOT NULL REFERENCES sources(id),
  ruling_ar TEXT,
  ruling_en TEXT,
  ruling_ur TEXT,
  volume TEXT,
  page TEXT,
  entry_number TEXT,
  verbatim_ar TEXT,
  verbatim_en TEXT,
  notes TEXT
);

-- General biography statements / fields with exact source citation.
CREATE TABLE IF NOT EXISTS references_cite (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  source_id INTEGER NOT NULL REFERENCES sources(id),
  field_key TEXT, -- e.g. birth, death, city, kunyah, general
  volume TEXT,
  page TEXT,
  entry_number TEXT,
  text_ar TEXT,
  text_en TEXT,
  text_ur TEXT,
  notes TEXT
);

-- Books where the biography appears (approved sources only).
CREATE TABLE IF NOT EXISTS books_mentioned (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  source_id INTEGER NOT NULL REFERENCES sources(id),
  volume TEXT,
  page TEXT,
  entry_number TEXT,
  notes TEXT
);

-- Verified mapping: hadith → primary narrator ID (never AI / text prediction).
CREATE TABLE IF NOT EXISTS hadith_relations (
  id INTEGER PRIMARY KEY,
  book_slug TEXT NOT NULL,
  hadith_number INTEGER NOT NULL,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'primary', -- primary | in_isnad
  isnad_position INTEGER,
  mapping_source TEXT NOT NULL, -- e.g. 'licensed_import:batch_1'
  UNIQUE (book_slug, hadith_number, narrator_id, role)
);

CREATE INDEX IF NOT EXISTS idx_hadith_rel_lookup
  ON hadith_relations(book_slug, hadith_number);

CREATE INDEX IF NOT EXISTS idx_narrators_slug ON narrators(slug);
