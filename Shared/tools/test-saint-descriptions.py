# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Checks safe offline source joins, attribution and missing-language behavior."""
import copy
import unittest

from saint_descriptions import add_sourced_descriptions, load_catalogue, validate_catalogue


class SaintDescriptionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalogue = load_catalogue()

    def enrich(self, days, calendar="roman"):
        return add_sourced_descriptions(days, calendar, self.catalogue)

    def test_does_not_attach_francis_to_a_sunday_on_the_same_date(self):
        days = {"2026-10-04": {"title": "27th Sunday of Ordinary Time", "rank": "Sunday"}}
        original = copy.deepcopy(days)
        self.assertEqual(self.enrich(days), 0)
        self.assertEqual(days, original)

    def test_exact_source_calendar_and_date_are_required(self):
        for date, calendar in (("2028-10-04", "roman"), ("2027-10-04", "ugcc")):
            days = {date: {"title": "Saint Francis of Assisi", "rank": "Memorial"}}
            self.assertEqual(self.enrich(days, calendar), 0)
            self.assertNotIn("observances", days[date])

    def test_no_name_normalization_or_substring_guess(self):
        for title in ("SAINT FRANCIS OF ASSISI", "Saint Francis Xavier", "Saint Francis of Assisi; St. Abi"):
            days = {"2027-10-04": {"title": title, "rank": "Memorial"}}
            self.assertEqual(self.enrich(days), 0)

    def test_legacy_dataset_preserves_sourced_titles_rank_and_language_maps(self):
        day = {"title": "Saint Francis of Assisi", "rank": "Memorial", "titleByLanguage": {"he": "כותרת מקור"}}
        days = {"2027-10-04": day}
        self.assertEqual(self.enrich(days), 1)
        self.assertEqual(day["title"], "Saint Francis of Assisi")
        self.assertEqual(day["rank"], "Memorial")
        self.assertEqual(day["titleByLanguage"], {"he": "כותרת מקור"})
        self.assertEqual(day["observances"][0]["titleByLanguage"], day["titleByLanguage"])
        self.assertIsNot(day["observances"][0]["titleByLanguage"], day["titleByLanguage"])

    def test_missing_languages_stay_absent_with_credit_for_each_actual_excerpt(self):
        days = {"2027-10-04": {"title": "Saint Francis of Assisi", "rank": "Memorial"}}
        self.enrich(days)
        part = days["2027-10-04"]["observances"][0]
        self.assertEqual(set(part["descriptionByLanguage"]), {"en", "ar", "fr", "it"})
        for language in part["descriptionByLanguage"]:
            self.assertIn("Evangelizo", part["descriptionCreditByLanguage"][language])
            self.assertTrue(part["descriptionSourceByLanguage"][language].startswith("https://"))

    def test_stjames_exact_role_suffix_spellings_and_existing_identity_are_preserved(self):
        part = {"title": "St. Faustina Kowalska, virgin", "identity": "saint faustina kowalska, virgin",
                "titleByLanguage": {"he": "כותרת הנציגות"}, "rank": "Optional Memorial"}
        days = {"2026-10-05": {"title": part["title"], "rank": "Optional Memorial", "observances": [part]}}
        self.assertEqual(self.enrich(days, "stjames"), 1)
        self.assertEqual(part["identity"], "saint faustina kowalska, virgin")
        self.assertEqual(part["titleByLanguage"], {"he": "כותרת הנציגות"})
        self.assertEqual(set(part["descriptionByLanguage"]), {"en", "fr", "it"})

    def test_franciscan_source_title_is_an_explicit_reviewed_alias(self):
        title = "S. P. N. FRANCESCO, fondatore dei Tre Ordini, patrono d’Italia. Solennità"
        days = {"2026-10-04": {"title": title, "rank": "Solemnity"}}
        self.assertEqual(self.enrich(days, "franciscan-conventual-italy"), 1)
        self.assertEqual(days["2026-10-04"]["title"], title)

    def test_independently_sourced_description_is_never_overwritten(self):
        part = {"title": "Our Lady of the Rosary", "identity": "our lady of the rosary",
                "descriptionByLanguage": {"he": "טקסט מקור", "en": "Reviewed independent prose"},
                "descriptionSourceByLanguage": {"he": "https://example.org/he", "en": "https://example.org/en"},
                "descriptionCreditByLanguage": {"he": "Independent Hebrew source", "en": "Independent source"}}
        days = {"2026-10-07": {"title": part["title"], "rank": "Memorial", "observances": [part]}}
        self.enrich(days, "stjames")
        self.assertEqual(part["descriptionByLanguage"]["en"], "Reviewed independent prose")
        self.assertEqual(part["descriptionByLanguage"]["he"], "טקסט מקור")
        self.assertEqual(part["descriptionSourceByLanguage"]["en"], "https://example.org/en")

    def test_rerun_is_idempotent(self):
        days = {"2027-10-07": {"title": "Our Lady of the Rosary", "rank": "Memorial"}}
        self.enrich(days)
        original = copy.deepcopy(days)
        self.enrich(days)
        self.assertEqual(days, original)

    def test_refresh_updates_the_same_single_observance_display_labels(self):
        day = {"title": "Our Lady of the Rosary", "rank": "Memorial", "titleByLanguage": {"fr": "ancien"}}
        days = {"2027-10-07": day}
        self.enrich(days)
        day["titleByLanguage"]["fr"] = "nouveau"
        self.enrich(days)
        self.assertEqual(day["observances"][0]["titleByLanguage"]["fr"], "nouveau")

    def test_removing_reviewed_source_removes_only_our_stale_prose(self):
        days = {"2027-10-07": {"title": "Our Lady of the Rosary", "rank": "Memorial"}}
        self.enrich(days)
        catalogue = copy.deepcopy(self.catalogue)
        catalogue["events"].pop("OurLadyOfTheRosary")
        self.assertEqual(add_sourced_descriptions(days, "roman", catalogue), 0)
        self.assertNotIn("descriptionByLanguage", days["2027-10-07"]["observances"][0])

    def test_ambiguous_join_is_rejected_before_mutation(self):
        catalogue = copy.deepcopy(self.catalogue)
        catalogue["events"]["WrongSaint"] = copy.deepcopy(catalogue["events"]["StFrancisAssisi"])
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            validate_catalogue(catalogue)

    def test_unsupported_language_and_missing_credit_are_rejected(self):
        catalogue = copy.deepcopy(self.catalogue)
        source = catalogue["events"]["StFrancisAssisi"]["descriptions"].pop("en")
        catalogue["events"]["StFrancisAssisi"]["descriptions"]["la"] = source
        with self.assertRaisesRegex(ValueError, "unsupported"):
            validate_catalogue(catalogue)
        catalogue = copy.deepcopy(self.catalogue)
        catalogue["events"]["StFrancisAssisi"]["descriptions"]["en"]["credit"] = ""
        with self.assertRaisesRegex(ValueError, "credit"):
            validate_catalogue(catalogue)


if __name__ == "__main__":
    unittest.main()
