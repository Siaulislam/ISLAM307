-- ISLAM307 Isnad Engine schema (narrators, sanads, review, citations)
-- Compiler is NOT a link in the rawi chain.
-- Only review_status='approved' rows are production sanads.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS compilers (
  id INTEGER PRIMARY KEY,
  book_slug TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  narrator_id INTEGER
);

CREATE TABLE IF NOT EXISTS narrators (
  id INTEGER PRIMARY KEY,
  display_name_ar TEXT NOT NULL,
  normalized_key TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Citation-ready biographical facts (empty until authenticated import).
CREATE TABLE IF NOT EXISTS narrator_citations (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL,
  field_key TEXT NOT NULL,
  field_value TEXT NOT NULL,
  book TEXT,
  author TEXT,
  volume TEXT,
  page TEXT,
  edition TEXT,
  publisher TEXT,
  notes TEXT,
  FOREIGN KEY (narrator_id) REFERENCES narrators(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS hadith_sanads (
  id INTEGER PRIMARY KEY,
  book_slug TEXT NOT NULL,
  hadith_number INTEGER NOT NULL,
  chain_index INTEGER NOT NULL DEFAULT 0,
  compiler_id INTEGER,
  isnad_ar TEXT,
  matn_ar TEXT,
  confidence REAL NOT NULL DEFAULT 0,
  review_status TEXT NOT NULL DEFAULT 'pending', -- pending|approved|rejected
  review_reasons TEXT,
  UNIQUE (book_slug, hadith_number, chain_index),
  FOREIGN KEY (compiler_id) REFERENCES compilers(id)
);

CREATE TABLE IF NOT EXISTS hadith_sanad_links (
  id INTEGER PRIMARY KEY,
  sanad_id INTEGER NOT NULL,
  position INTEGER NOT NULL,
  narrator_id INTEGER,
  transmission_verb TEXT,
  relation_type TEXT,
  relative_to_position INTEGER,
  resolved_from_relative INTEGER NOT NULL DEFAULT 0,
  surface_form TEXT,
  FOREIGN KEY (sanad_id) REFERENCES hadith_sanads(id) ON DELETE CASCADE,
  FOREIGN KEY (narrator_id) REFERENCES narrators(id),
  UNIQUE (sanad_id, position)
);

CREATE TABLE IF NOT EXISTS sanad_review_queue (
  id INTEGER PRIMARY KEY,
  book_slug TEXT NOT NULL,
  hadith_number INTEGER NOT NULL,
  sanad_id INTEGER,
  confidence REAL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open', -- open|approved|rejected
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (sanad_id) REFERENCES hadith_sanads(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_sanads_book_num ON hadith_sanads(book_slug, hadith_number);
CREATE INDEX IF NOT EXISTS idx_review_open ON sanad_review_queue(status);
CREATE INDEX IF NOT EXISTS idx_narrator_key ON narrators(normalized_key);
