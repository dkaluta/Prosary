using System.Reflection;
using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Guards against silent content gaps. Two layers:
/// 1. The hardcoded tables (main prayers, Rosary keys, antiphons, Jesus Prayer) — every surviving
///    <see cref="PrayerKey"/> must have all six languages; PrayerTranslations.Get silently falls
///    back to Latin, so a gap wouldn't otherwise surface until someone prays in that language.
/// 2. Every shipped devotion bundle — each key its devotion.json references must resolve to real
///    text (never the raw key) in every language the bundle's manifest declares, with each
///    bundle's known gaps listed explicitly so they go stale loudly instead of silently wrong.
///    Mirrors Shared/tools/validate-devotion.py, but against the actually-shipped packs and the
///    runtime merge (e.g. the Franciscan Crown's shared Joys resolving cross-bundle from the
///    rosary pack). Mirrors iOS's PrayerTranslationsCompletenessTests.swift / Android's
///    PrayerTranslationsCompletenessTest.kt.
/// </summary>
public class PrayerTranslationsCompletenessTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerTranslationsCompletenessTests(PrayerPackLoaderFixture _)
    {
    }

    private static readonly string[] AllLanguages = ["la", "en", "ar", "he", "ru", "tl"];

    /// <summary><see cref="PrayerKey.DoxologiaMinor"/> is explicitly documented ("kept for
    /// future use") as reserved but not wired into any devotion's engine code yet — it has no
    /// Latin/English content at all (only a Hebrew entry, added manually), so it can't satisfy
    /// even the baseline check. Excluded here rather than fabricating placeholder Latin/English
    /// text for a key nothing reads yet.</summary>
    private static readonly HashSet<string> NotYetUsedByAnyDevotion = [PrayerKey.DoxologiaMinor];

    /// <summary>Known per-bundle translation gaps: bundleId -> language -> keys awaiting a
    /// verified translation. The self-guard test below fails once a listed key gains its
    /// translation, so this map can never go silently stale.</summary>
    private static readonly Dictionary<string, Dictionary<string, string[]>> BundleKeysMissingLanguages = new()
    {
        // Veronica's station quotes Judith, and the Arabic/Tagalog scripture sources carry no
        // deuterocanon — those two follow the configured fallback order (English by default).
        ["stationsOfTheCross"] = new()
        {
            ["ar"] = ["station06Body"],
            ["tl"] = ["station06Body"],
        },
    };

    private static IEnumerable<string> AllPrayerKeys() =>
        typeof(PrayerKey).GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral)
            .Select(f => (string)f.GetRawConstantValue()!);

    private static IEnumerable<string> AllMysteryImageKeys() =>
        Enum.GetValues<MysteryGroup>().SelectMany(MysteryCatalog.ForGroup).Select(m => m.ImageKey);

    // Hardcoded tables

    [Fact]
    public void EveryPrayerKeyHasAllSixLanguages()
    {
        foreach (var key in AllPrayerKeys().Where(k => !NotYetUsedByAnyDevotion.Contains(k)))
        {
            foreach (var language in AllLanguages)
            {
                var text = PrayerTranslations.ByLanguage[language].GetValueOrDefault(key);
                Assert.False(string.IsNullOrEmpty(text), $"{key} missing a {language} translation");
            }
        }
    }

    /// <summary>The cross mark shows where the sign of the cross is made. It has to be in every
    /// language's Sign of the Cross — a reader who prays in Tagalog needs it as much as one who
    /// prays in Hebrew — and it belongs immediately after the word for "Father", where the
    /// gesture begins, which is where the Mission of St. Gamaliel's own texts put it. Dropping it
    /// is the kind of thing that happens silently when someone re-types a prayer.</summary>
    [Fact]
    public void EverySignOfTheCrossCarriesTheCrossMark()
    {
        foreach (var (language, table) in PrayerTranslations.ByLanguage)
        {
            if (!table.TryGetValue(PrayerKey.SignumCrucis, out var text)) continue;
            Assert.Contains("\u2720", text);
            var trimmed = text.Trim();
            Assert.False(trimmed.StartsWith("\u2720") || trimmed.EndsWith("\u2720"),
                $"{language}: the mark should sit inside the formula");
        }
    }

    /// <summary>...and nowhere else outside the Mission's own rite. Signing at the Glory Be is
    /// their use, not the Latin rite's, and quietly spreading it would be inventing
    /// practice.</summary>
    [Fact]
    public void TheCrossMarkStaysOutOfOtherRitesPrayers()
    {
        foreach (var (language, table) in PrayerTranslations.ByLanguage)
        {
            if (language == "he-x-gamliel") continue;
            foreach (var (key, text) in table)
            {
                if (key == PrayerKey.SignumCrucis) continue;
                Assert.False(text.Contains("\u2720"),
                    $"{language}'s {key} should not carry a cross mark");
            }
        }
    }

    [Fact]
    public void EveryRosaryMysteryImageKeyHasAllSixLanguages()
    {
        foreach (var imageKey in AllMysteryImageKeys().Distinct())
        {
            foreach (var language in AllLanguages)
            {
                Assert.True(
                    MysteryTranslations.ByLanguage[language].ContainsKey(imageKey),
                    $"{imageKey} missing a {language} translation");
            }
        }
    }

    // Shipped bundles

    /// <summary>Collects every bodyKey/titleKey a definition references, and the mystery
    /// imageKeys whose text an announced decade needs.</summary>
    private static (HashSet<string> Text, HashSet<string> Mysteries) ReferencedKeys(CustomDevotionDefinition definition)
    {
        var text = new HashSet<string>();
        var mysteries = new HashSet<string>();
        var allEntries = (definition.Steps ?? []).Concat(definition.EastertideSteps ?? [])
            .Concat(definition.Opening ?? []).Concat(definition.Closing ?? [])
            .Concat((definition.Variants ?? []).SelectMany(v => (v.Steps ?? []).Concat(v.EastertideSteps ?? [])));
        foreach (var entry in allEntries.Where(e => e.Kind is null))
        {
            if (entry.BodyKey is { } bodyKey) text.Add(bodyKey);
            if (entry.TitleKey is { } titleKey) text.Add(titleKey);
        }

        if (definition.Decades is { } decades)
        {
            text.Add(decades.MajorStep.BodyKey);
            text.Add(decades.MinorStep.BodyKey);
            if (decades.AnnounceMystery)
            {
                foreach (var entry in decades.Entries ?? []) mysteries.Add(entry.ImageKey);
            }
        }

        return (text, mysteries);
    }

    [Fact]
    public void EveryBundleKeyResolvesInEveryDeclaredLanguage()
    {
        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            var definition = PrayerPackStore.Definition(bundleId);
            var info = PrayerPackStore.Info(bundleId);
            Assert.True(definition is not null && info is not null, $"{bundleId}: missing definition or info");

            var (textKeys, mysteryKeys) = ReferencedKeys(definition!);
            foreach (var language in info!.Languages)
            {
                var allowedMissing = BundleKeysMissingLanguages.GetValueOrDefault(bundleId)?.GetValueOrDefault(language) ?? [];
                foreach (var key in textKeys.Where(k => !allowedMissing.Contains(k)))
                {
                    var resolved = PrayerPackStore.ResolveBodyText(bundleId, language, key);
                    Assert.True(
                        resolved != key,
                        $"{bundleId}/{language}: {key} resolves to its raw key — missing translation");
                }

                foreach (var imageKey in mysteryKeys)
                {
                    var mystery = MysteryTranslations.Get(language, imageKey);
                    Assert.True(
                        mystery.Title != imageKey,
                        $"{bundleId}/{language}: no mystery text for {imageKey}");
                }
            }
        }
    }

    /// <summary>Guards the gap allowlist itself from going stale: once a listed key gains a
    /// translation, this fails as a reminder to narrow the allowlist rather than leaving it
    /// inaccurate.</summary>
    [Fact]
    public void AllowlistedBundleKeysAreStillMissingFromTheExpectedLanguages()
    {
        foreach (var (bundleId, languages) in BundleKeysMissingLanguages)
        {
            foreach (var (language, keys) in languages)
            {
                foreach (var key in keys)
                {
                    var resolved = PrayerPackStore.ResolveBodyText(bundleId, language, key);
                    // These keys are absent from the requested language and therefore follow the
                    // user's precedence list. The default order's first applicable language is
                    // English; equality keeps the allowlist honest without assuming Latin is the
                    // only possible fallback.
                    var fallback = PrayerPackStore.ResolveBodyText(bundleId, "en", key);
                    Assert.True(
                        resolved == fallback,
                        $"{bundleId}/{language}: {key} now has its own translation — narrow BundleKeysMissingLanguages");
                }
            }
        }
    }
}
