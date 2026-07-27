using System.Reflection;
using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Guards against a missed cell in the per-language content tables — PrayerTranslations.Get/
/// MysteryTranslations.Get silently fall back to Latin (then the raw key) when a translation is
/// missing, so a gap here wouldn't otherwise surface until someone actually reads that language
/// in the app. Mirrors iOS's PrayerTranslationsCompletenessTests.swift / Android's
/// PrayerTranslationsCompletenessTest.kt.
/// </summary>
public class PrayerTranslationsCompletenessTests
{
    private static readonly string[] FullyTranslatedLanguages = ["ar", "he", "ru", "tl"];

    /// <summary>Keys added during the 4-devotion rollout (Stations of the Cross, Seven Sorrows,
    /// Divine Mercy Chaplet) that are still missing one or more of the 4 non-Latin/English
    /// languages, mapped to exactly which of those 4 they're still missing — silently falls back
    /// to Latin for those via the normal fallback chain, not a bug. Kept explicit here so a
    /// *new*, unintentional gap still fails <see cref="EveryKeyExceptTheKnownAllowlistHasAllSixLanguages"/>,
    /// and so this map itself goes stale (rather than silently wrong) once a language is filled
    /// in — see <see cref="AllowlistedPrayerKeysAreStillMissingFromTheExpectedLanguages"/>.</summary>
    private static readonly Dictionary<string, string[]> PrayerKeysMissingLanguages = new()
    {
        [PrayerKey.StationsOpeningPrayer] = ["ar", "he", "ru", "tl"],
        [PrayerKey.StationsVersicle] = ["ar", "he", "ru", "tl"],
        [PrayerKey.StationsResponse] = ["ar", "he", "ru", "tl"],
        [PrayerKey.StationsClosingPrayer] = ["ar", "he", "ru", "tl"],
        [PrayerKey.SevenSorrowsVersicle] = ["ar", "he", "ru", "tl"],
        [PrayerKey.SevenSorrowsResponse] = ["ar", "he", "ru", "tl"],
        [PrayerKey.SevenSorrowsCollect] = ["ar", "he", "ru", "tl"],
        [PrayerKey.DivineMercyOffering] = ["ar", "he", "ru", "tl"],
        [PrayerKey.DivineMercyPetition] = ["ar", "he", "ru", "tl"],
        // Hebrew added by the user directly — see PrayerTranslations.Hebrew.cs.
        [PrayerKey.DivineMercyClosingAcclamation] = ["ar", "ru", "tl"],
    };

    /// <summary>Same idea as <see cref="PrayerKeysMissingLanguages"/>, for MysteryTranslations —
    /// the Seven Sorrows' 7 imageKeys and the Franciscan Crown's one new mystery (Adoration of
    /// the Magi; the other 6 Joys reuse existing, fully-translated Rosary mystery content).</summary>
    private static readonly HashSet<string> LatinAndEnglishOnlyMysteryImageKeys =
        [.. SevenSorrowsCatalog.SevenSorrows, "franciscan_04_adoration_of_the_magi"];

    /// <summary><see cref="PrayerKey.DoxologiaMinor"/> is explicitly documented ("kept for
    /// future use") as reserved but not wired into any devotion's engine code yet — it has no
    /// Latin/English content at all (only a Hebrew entry, added manually), so it can't satisfy
    /// even the baseline <see cref="EveryPrayerKeyHasLatinAndEnglishTranslations"/> check.
    /// Excluded here rather than fabricating placeholder Latin/English text for a key nothing
    /// reads yet.</summary>
    private static readonly HashSet<string> NotYetUsedByAnyDevotion = [PrayerKey.DoxologiaMinor];

    private static IEnumerable<string> AllPrayerKeys() =>
        typeof(PrayerKey).GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral)
            .Select(f => (string)f.GetRawConstantValue()!);

    private static IEnumerable<string> AllMysteryImageKeys() =>
        Enum.GetValues<MysteryGroup>().SelectMany(MysteryCatalog.ForGroup).Select(m => m.ImageKey)
            .Union(SevenSorrowsCatalog.SevenSorrows)
            .Union(FranciscanCrownCatalog.SevenJoys);

    [Fact]
    public void EveryPrayerKeyHasLatinAndEnglishTranslations()
    {
        foreach (var key in AllPrayerKeys().Where(k => !NotYetUsedByAnyDevotion.Contains(k)))
        {
            foreach (var language in new[] { "la", "en" })
            {
                var text = PrayerTranslations.ByLanguage[language].GetValueOrDefault(key);
                Assert.False(string.IsNullOrEmpty(text), $"{key} missing a {language} translation");
            }
        }
    }

    [Fact]
    public void EveryKeyExceptTheKnownAllowlistHasAllSixLanguages()
    {
        foreach (var key in AllPrayerKeys().Where(k => !NotYetUsedByAnyDevotion.Contains(k)))
        {
            var missing = PrayerKeysMissingLanguages.GetValueOrDefault(key, []);
            foreach (var language in FullyTranslatedLanguages.Where(l => !missing.Contains(l)))
            {
                var text = PrayerTranslations.ByLanguage[language].GetValueOrDefault(key);
                Assert.False(
                    string.IsNullOrEmpty(text),
                    $"{key} missing a {language} translation — if intentional, add it to PrayerKeysMissingLanguages");
            }
        }
    }

    /// <summary>Guards the allowlist itself from going stale: if a key gets translated into a
    /// language still listed as missing for it, this should start failing as a reminder to
    /// narrow that key's entry in <see cref="PrayerKeysMissingLanguages"/> (or remove it
    /// entirely) rather than leaving a passing-but-inaccurate entry.</summary>
    [Fact]
    public void AllowlistedPrayerKeysAreStillMissingFromTheExpectedLanguages()
    {
        foreach (var (key, missing) in PrayerKeysMissingLanguages)
        {
            foreach (var language in missing)
            {
                Assert.False(
                    PrayerTranslations.ByLanguage[language].ContainsKey(key),
                    $"{key} now has a {language} translation — narrow or remove its entry in PrayerKeysMissingLanguages");
            }
        }
    }

    [Fact]
    public void EveryMysteryImageKeyHasLatinAndEnglishTranslations()
    {
        foreach (var imageKey in AllMysteryImageKeys().Distinct())
        {
            foreach (var language in new[] { "la", "en" })
            {
                Assert.True(
                    MysteryTranslations.ByLanguage[language].ContainsKey(imageKey),
                    $"{imageKey} missing a {language} translation");
            }
        }
    }

    [Fact]
    public void EveryMysteryImageKeyExceptTheKnownAllowlistHasAllSixLanguages()
    {
        foreach (var imageKey in AllMysteryImageKeys().Distinct().Where(k => !LatinAndEnglishOnlyMysteryImageKeys.Contains(k)))
        {
            foreach (var language in FullyTranslatedLanguages)
            {
                Assert.True(
                    MysteryTranslations.ByLanguage[language].ContainsKey(imageKey),
                    $"{imageKey} missing a {language} translation — if intentional, add it to LatinAndEnglishOnlyMysteryImageKeys");
            }
        }
    }

    [Fact]
    public void AllowlistedMysteryImageKeysAreStillMissingFromTheExpectedLanguages()
    {
        foreach (var imageKey in LatinAndEnglishOnlyMysteryImageKeys)
        {
            foreach (var language in FullyTranslatedLanguages)
            {
                Assert.False(
                    MysteryTranslations.ByLanguage[language].ContainsKey(imageKey),
                    $"{imageKey} now has a {language} translation — remove it from LatinAndEnglishOnlyMysteryImageKeys");
            }
        }
    }
}
