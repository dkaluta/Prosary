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
        ["divineMercyChaplet"] = new() { ["he"] = ["divineMercyOffering", "divineMercyPetition"] },
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
            .Concat(definition.Opening ?? []).Concat(definition.Closing ?? []);
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
                    // A missing bundle-local translation falls back to the bundle's Latin text
                    // (or the hardcoded chain) — "still missing" means it doesn't resolve to
                    // language-specific bundle content, i.e. it equals the Latin resolution.
                    var latin = PrayerPackStore.ResolveBodyText(bundleId, "la", key);
                    Assert.True(
                        resolved == latin,
                        $"{bundleId}/{language}: {key} now has its own translation — narrow BundleKeysMissingLanguages");
                }
            }
        }
    }
}
