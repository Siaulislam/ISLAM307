-- Future licensed narrator (rijāl) pack schema for ISLAM 307.
-- Do not invent rows. Populate only from an officially licensed dataset.
-- Hadith reader looks up by normalized alias; missing hits show the offline-unavailable message.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  license TEXT,
  attribution TEXT,
  url TEXT
);

CREATE TABLE IF NOT EXISTS narrators (
  id INTEGER PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name_ar TEXT,
  name_en TEXT,
  name_ur TEXT,
  -- companion | tabii | tab_tabii | scholar | unknown — only when authenticated
  narrator_type TEXT,
  birth_hijri TEXT,
  death_hijri TEXT,
  bio_ar TEXT,
  bio_en TEXT,
  bio_ur TEXT,
  source_id INTEGER REFERENCES sources(id),
  license_ref TEXT
);

CREATE TABLE IF NOT EXISTS name_aliases (
  id INTEGER PRIMARY KEY,
  narrator_id INTEGER NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  lang TEXT NOT NULL,
  alias TEXT NOT NULL,
  alias_normalized TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_aliases_norm ON name_aliases(alias_normalized);
CREATE INDEX IF NOT EXISTS idx_aliases_lang ON name_aliases(lang, alias_normalized);
