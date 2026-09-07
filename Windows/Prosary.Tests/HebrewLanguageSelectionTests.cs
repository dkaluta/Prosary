using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class HebrewLanguageSelectionTests : IClassFixture<PrayerPackLoaderFixture>
{
    private const string Mission = "he-x-gamliel";

    public HebrewLanguageSelectionTests(PrayerPackLoaderFixture _) { }

    private static void WithOrder(string[] order, Action check)
    {
        var previous = AppSettings.LanguageFallbackOrder.ToArray();
        try { AppSettings.SetLanguageFallbackOrder(order); check(); }
        finally { AppSettings.SetLanguageFallbackOrder(previous); }
    }

    [Fact]
    public void EnteringHebrewUsesFirstSavedTraditionFromOtherLanguagesAndAppSetting()
    {
        foreach (var order in new[] { new[] { Mission, "arc", "he" }, new[] { "he", "arc", Mission } })
            WithOrder(order, () =>
            {
                foreach (var current in LanguageCatalog.All.Select(option => option.Code).Where(code => code != "he" && code != Mission).Append(""))
                    Assert.Equal(order[0], LanguageCatalog.SelectingLanguage("he", current));
                Assert.Equal(order, AppSettings.LanguageFallbackOrder);
            });
    }

    [Fact]
    public void AlreadySelectedHebrewTraditionRemainsExplicitInEitherOrder()
    {
        foreach (var order in new[] { new[] { Mission, "arc", "he" }, new[] { "he", "arc", Mission } })
            WithOrder(order, () =>
            {
                foreach (var current in new[] { "he", Mission })
                    Assert.Equal(current, LanguageCatalog.SelectingLanguage("he", current));
            });
    }

    [Fact]
    public void LeavingHebrewAndReturningUsesPriorityAgain()
    {
        foreach (var (order, previous) in new[] { (new[] { Mission, "arc", "he" }, "he"), (new[] { "he", "arc", Mission }, Mission) })
            WithOrder(order, () =>
            {
                var english = LanguageCatalog.SelectingLanguage("en", previous);
                Assert.Equal("en", english);
                Assert.Equal(order[0], LanguageCatalog.SelectingLanguage("he", english));
            });
    }

    [Fact]
    public void OtherLanguageAndEmptyChoicesArePassedThrough() => WithOrder([Mission, "arc", "he"], () =>
    {
        foreach (var next in LanguageCatalog.All.Select(option => option.Code).Where(code => code != "he").Concat(["", "unknown"]))
        foreach (var current in new[] { "he", Mission, "en", "" })
            Assert.Equal(next, LanguageCatalog.SelectingLanguage(next, current));
    });

    [Fact]
    public void EmptyAndDamagedSavedOrdersUseOnlyKnownDistinctTraditions()
    {
        foreach (var (order, expected) in new[] {
            (Array.Empty<string>(), "he"), (new[] { "unknown" }, "he"),
            (new[] { "unknown", LanguageCatalog.VicariateContentCode, Mission, Mission, "arc", "he" }, Mission),
            (new[] { "unknown", "he", "he", "arc", Mission }, "he"),
        }) WithOrder(order, () =>
        {
            Assert.Equal(expected, LanguageCatalog.SelectingLanguage("he", ""));
            Assert.Single(LanguageCatalog.FallbackOrder, code => code == expected);
            Assert.DoesNotContain("unknown", LanguageCatalog.FallbackOrder);
            Assert.DoesNotContain(LanguageCatalog.VicariateContentCode, LanguageCatalog.FallbackOrder);
        });
    }

    [Fact]
    public void SelectedMissionCodeReachesItsRealPrayerTextAndAppDefault() => WithOrder([Mission, "arc", "he"], () =>
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        try
        {
            var prayer = BasicPrayerCatalog.Prayer("ourFather")!;
            var expected = PrayerTranslations.ByLanguage[Mission][PrayerKey.PaterNoster];
            var selected = LanguageCatalog.SelectingLanguage("he", "en");
            var step = BasicPrayerCatalog.Step(prayer, selected);
            Assert.Equal(expected, step.Body);
            Assert.Equal("תפילת האדון", step.Title);
            Assert.NotEqual(step.Body, BasicPrayerCatalog.Step(prayer, "he").Body);
            AppSettings.SetDefaultLanguageCode(selected);
            Assert.Equal(expected, BasicPrayerCatalog.Step(prayer, "").Body);
            Assert.Equal(Mission, LanguageCatalog.Resolve("").Code);
        }
        finally { AppSettings.SetDefaultLanguageCode(previousDefault); }
    });
}
