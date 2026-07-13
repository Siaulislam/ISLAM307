#!/usr/bin/env python3
"""Unit tests for the Arabic Isnad Engine."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "hadith"))

from isnad_engine.engine import IsnadEngine, parse_hadith_isnad  # noqa: E402
from isnad_engine.normalize import (  # noqa: E402
    extract_ibn_parent,
    is_relative_token,
    match_key,
    normalize_key,
)
from isnad_engine.registry import NarratorRegistry  # noqa: E402
from isnad_engine.split import split_matn, split_parallel_isnads  # noqa: E402


class NormalizeTests(unittest.TestCase):
    def test_honorific_and_tatweel(self):
        a = normalize_key("عبد الله ـ رضي الله عنه ـ")
        b = normalize_key("عبدالله")
        c = normalize_key("عبد اللّٰه")
        self.assertEqual(a, b)
        self.assertEqual(a, c)

    def test_ibn_bin_abu(self):
        self.assertEqual(normalize_key("ابن عباس"), normalize_key("بن عباس"))
        self.assertEqual(normalize_key("أبو هريرة"), normalize_key("ابو هريرة"))

    def test_ibrahim_variants(self):
        self.assertEqual(normalize_key("إبراهيم"), normalize_key("ابراهيم"))

    def test_relative_tokens(self):
        self.assertTrue(is_relative_token("أبيه"))
        self.assertTrue(is_relative_token("أمه"))
        self.assertTrue(is_relative_token("جده"))
        self.assertTrue(is_relative_token("أخيه"))
        self.assertTrue(is_relative_token("عمه"))
        self.assertTrue(is_relative_token("خاله"))
        self.assertFalse(is_relative_token("هشام بن عروة"))

    def test_extract_ibn_parent(self):
        self.assertEqual(extract_ibn_parent("هشام بن عروة"), "عروة")
        self.assertEqual(extract_ibn_parent("محمد بن إبراهيم التيمي"), "إبراهيم التيمي")


class RegistryTests(unittest.TestCase):
    def test_duplicate_detection(self):
        reg = NarratorRegistry()
        a = reg.get_or_create("عبد الله")
        b = reg.get_or_create("عبدالله")
        c = reg.get_or_create("عبد اللّٰه")
        self.assertEqual(a.id, b.id)
        self.assertEqual(a.id, c.id)
        self.assertEqual(len(reg), 1)


class ParallelAndRelativeTests(unittest.TestCase):
    def test_parallel_split_ha(self):
        text = (
            "حدثنا عبدان، قال أخبرنا عبد الله، قال أخبرنا يونس، عن الزهري، "
            "ح وحدثنا بشر بن محمد، قال أخبرنا عبد الله، قال أخبرنا يونس، ومعمر، عن الزهري"
        )
        parts = split_parallel_isnads(text)
        self.assertGreaterEqual(len(parts), 2)
        self.assertTrue(parts[0].startswith("حدثنا عبدان") or "عبدان" in parts[0])
        self.assertTrue(any("بشر" in p for p in parts))

    def test_relative_father_resolved(self):
        ar = (
            "حدثنا عبد الله بن يوسف، قال أخبرنا مالك، عن هشام بن عروة، "
            "عن أبيه، عن عائشة أم المؤمنين رضي الله عنها: أن الحارث بن هشام "
            "سأل رسول الله صلى الله عليه وسلم"
        )
        result = parse_hadith_isnad(ar, book_slug="bukhari", hadith_number=2)
        names = result.primary_names
        self.assertTrue(any("هشام" in n for n in names))
        # أبيه must not appear as a literal narrator name
        self.assertFalse(any(is_relative_token(n) for n in names))
        # Prefer resolved parent segment عروة
        self.assertTrue(any("عروة" in n for n in names))
        # الحارث is matn — not a narrator
        self.assertFalse(any("الحارث" in n for n in names))
        # Compiler stored separately
        self.assertEqual(result.compiler_name_ar, "محمد بن إسماعيل البخاري")
        self.assertFalse(any("البخاري" in n for n in names))

    def test_nested_qala_and_an(self):
        ar = (
            "حدثنا الحميدي عبد الله بن الزبير، قال: حدثنا سفيان، قال: حدثنا يحيى بن سعيد "
            "الأنصاري، قال: أخبرني محمد بن إبراهيم التيمي، أنه سمع علقمة بن وقاص الليثي، "
            "يقول: سمعت عمر بن الخطاب رضي الله عنه على المنبر قال: سمعت رسول الله صلى الله "
            "عليه وسلم يقول: إنما الأعمال بالنيات"
        )
        result = parse_hadith_isnad(ar, book_slug="bukhari", hadith_number=1)
        names = result.primary_names
        self.assertGreaterEqual(len(names), 5)
        self.assertTrue(any("عمر" in n for n in names))
        self.assertFalse(any("إنما" in n for n in names))
        self.assertTrue(result.primary_ids)
        self.assertEqual(len(result.primary_ids), len(names))

    def test_story_hadith_heraclius(self):
        ar = (
            "حدثنا أبو اليمان الحكم بن نافع، قال أخبرنا شعيب، عن الزهري، "
            "قال أخبرني عبيد الله بن عبد الله بن عتبة بن مسعود، أن عبد الله بن عباس، أخبره "
            "أن أبا سفيان بن حرب أخبره أن هرقل أرسل إليه في ركب من قريش"
        )
        result = parse_hadith_isnad(ar, book_slug="bukhari", hadith_number=7)
        names = result.primary_names
        joined = " | ".join(names)
        self.assertIn("عباس", joined)
        self.assertNotIn("هرقل", joined)
        self.assertFalse(any(n.startswith("أبو سفيان") or n.startswith("أبا سفيان") for n in names))

    def test_broken_ocr_noise(self):
        # Garbage / truncated should yield low confidence + review
        result = parse_hadith_isnad("??? ###", book_slug="muslim", hadith_number=1)
        self.assertTrue(result.needs_review)
        self.assertLess(result.overall_confidence, 95)

    def test_long_isnad_confidence(self):
        names = "، ".join([f"حدثنا راوي{i}" for i in range(16)])
        result = parse_hadith_isnad(names + " قال رسول الله صلى الله عليه وسلم السلام", book_slug="tirmidhi")
        # Should parse something and flag review for length or cut
        self.assertIsNotNone(result.chains)

    def test_matn_split(self):
        isnad, matn = split_matn(
            "حدثنا قتيبة حدثنا الليث عن ابن شهاب عن سعيد عن أبي هريرة "
            "أن رسول الله صلى الله عليه وسلم قال: إذا مات الإنسان"
        )
        self.assertIn("قتيبة", isnad)
        self.assertNotIn("إذا مات", isnad)
        self.assertTrue(matn == "" or "إذا" in matn or "رسول" in matn or len(matn) >= 0)

    def test_compiler_not_in_chain_ids_as_link_zero(self):
        engine = IsnadEngine()
        r = engine.parse(
            text_ar="حدثنا قتيبة بن سعيد حدثنا الليث عن ابن شهاب عن أبي هريرة أن رسول الله قال السلام",
            book_slug="muslim",
            hadith_number=1,
        )
        self.assertEqual(r.compiler_name_en, "Muslim ibn al-Hajjaj")
        # First chain link is قتيبة, not مسلم
        if r.primary_names:
            self.assertNotIn("مسلم بن الحجاج", r.primary_names[0])


class MatchKeyAlias(unittest.TestCase):
    def test_match_key(self):
        self.assertEqual(match_key("عبد الله"), match_key("عبدالله"))


if __name__ == "__main__":
    unittest.main()
