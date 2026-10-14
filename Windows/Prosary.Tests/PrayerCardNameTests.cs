using Prosary.Localization;
using Prosary.Models;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerCardNameTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerCardNameTests(PrayerPackLoaderFixture _) { }

    [Fact]
    public void DefaultUsesInterfaceAndOptInAddsOnlyADistinctSubtitle()
    {
        Assert.Equal(new PrayerCardName("Rosary", ""), PrayerCardName.Resolve("Rosary", "מחרוזת", false));
        Assert.Equal(new PrayerCardName("מחרוזת", "Rosary"), PrayerCardName.Resolve("Rosary", "מחרוזת", true));
        Assert.Equal(new PrayerCardName("Rosary", ""), PrayerCardName.Resolve("Rosary", "Rosary", true));
    }

    [Theory]
    [InlineData("he", "אבינו שבשמים")]
    [InlineData("he-x-gamliel", "תפילת האדון")]
    [InlineData("arc", "צלותא מרניתא")]
    [InlineData("uk", "Отче наш")]
    [InlineData("en", "Our Father")]
    public void BasicCardPreferenceOnlyAddsInterfaceSubtitleAndKeepsTheSelectedPrayer(
        string language, string expectedTitle)
    {
        var old = AppSettings.ShowPrayerNameInPrayerLanguage;
        try
        {
            var prayer = BasicPrayerCatalog.Prayer("ourFather")!;
            var original = BasicPrayerCatalog.Step(prayer, language);
            Assert.False(string.IsNullOrWhiteSpace(original.Body));
            foreach (var enabled in new[] { false, true, false })
            {
                AppSettings.SetShowPrayerNameInPrayerLanguage(enabled);
                // The selected prayer/tradition stays primary even with the option off.
                // An explicit interface language keeps this independent of the test host.
                var name = PrayerCardName.ForBasicPrayer(prayer, language, "en");
                Assert.Equal(expectedTitle, name.Title);
                Assert.Equal(enabled && expectedTitle != "Our Father" ? "Our Father" : "", name.InterfaceSubtitle);
                var current = BasicPrayerCatalog.Step(prayer, language);
                Assert.Equal(expectedTitle, current.Title);
                Assert.Equal(original.Body, current.Body);
                Assert.Equal(original.TransliteratedBody, current.TransliteratedBody);
            }
        }
        finally { AppSettings.SetShowPrayerNameInPrayerLanguage(old); }
    }

    [Fact]
    public void BilingualCardKeepsDescriptiveStatusAndOmitsDuplicateNames()
    {
        var card = new DevotionCardModel
        {
            Id = "test", Title = "מחרוזת", InterfaceSubtitle = "Rosary", Subtitle = "Day 2 of 9",
            IconGlyph = "", Command = new CommunityToolkit.Mvvm.Input.RelayCommand(() => { }),
        };
        Assert.Equal($"Rosary{Environment.NewLine}Day 2 of 9", card.DisplaySubtitle);
        card.Subtitle = "Rosary";
        Assert.Equal("Rosary", card.DisplaySubtitle);
        card.InterfaceSubtitle = "";
        card.Subtitle = "מחרוזת";
        Assert.Equal("", card.DisplaySubtitle);
    }

    [Theory]
    [InlineData("he", "he-x-gamliel", "אבינו שבשמים", "אני מאמין", "אני מאמין של ניקיאה")]
    [InlineData("he-x-gamliel", "he", "תפילת האדון", "מאמינים של ניקאה", "מאמינים של ניקאה")]
    public void HebrewBasicCardsAndHeadersUseThePickedRiteDespiteAnOppositeGlobalDefault(
        string selectedRite, string globalRite, string fatherTitle, string creedTitle, string niceneTitle)
    {
        var oldUi = UiLanguageCatalog.Current;
        var oldDefault = AppSettings.PrayerLanguageCode;
        var oldBasic = AppSettings.BasicPrayersLanguageCode;
        var oldNames = AppSettings.ShowPrayerNameInPrayerLanguage;
        var oldOrder = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            AppSettings.SetDefaultLanguageCode(globalRite);
            AppSettings.SetBasicPrayersLanguageCode(selectedRite);
            AppSettings.SetLanguageFallbackOrder(["he-x-gamliel", "he", "en", "la"]);
            foreach (var enabled in new[] { false, true })
            {
                AppSettings.SetShowPrayerNameInPrayerLanguage(enabled);
                foreach (var (id, expected) in new[] { ("ourFather", fatherTitle), ("creed", creedTitle), ("niceneCreed", niceneTitle) })
                {
                    var prayer = BasicPrayerCatalog.Prayer(id)!;
                    if (!BasicPrayerCatalog.IsAvailable(prayer, selectedRite))
                    {
                        Assert.DoesNotContain(BasicPrayerCatalog.Available(selectedRite), item => item.Id == id);
                        var unavailable = new BasicPrayerViewModel();
                        unavailable.Load(id);
                        Assert.Empty(unavailable.Body);
                        continue;
                    }
                    var name = PrayerCardName.ForBasicPrayer(prayer, selectedRite);
                    Assert.Equal(expected, name.Title);
                    Assert.Empty(name.InterfaceSubtitle);
                    var reader = new BasicPrayerViewModel();
                    reader.Load(id);
                    Assert.Equal(expected, reader.Header);
                    Assert.Equal(BasicPrayerCatalog.Step(prayer, selectedRite).Body, reader.Body);
                }
            }
        }
        finally
        {
            UiLanguageCatalog.UseLanguageForCurrentSession(oldUi);
            AppSettings.SetDefaultLanguageCode(oldDefault);
            AppSettings.SetBasicPrayersLanguageCode(oldBasic);
            AppSettings.SetShowPrayerNameInPrayerLanguage(oldNames);
            AppSettings.SetLanguageFallbackOrder(oldOrder);
        }
    }

    [Theory]
    [InlineData("he", "he-x-gamliel", "טריסאגיון")]
    [InlineData("he-x-gamliel", "he", "קדישת")]
    public void HebrewDevotionCardsUseTheirOwnRiteAndGalleryUsesTheGlobalRite(
        string selectedRite, string globalRite, string expected)
    {
        var oldUi = UiLanguageCatalog.Current;
        var oldDefault = AppSettings.PrayerLanguageCode;
        var oldNames = AppSettings.ShowPrayerNameInPrayerLanguage;
        var oldOrder = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            AppSettings.SetDefaultLanguageCode(globalRite);
            AppSettings.SetLanguageFallbackOrder(["he-x-gamliel", "he", "en", "la"]);
            foreach (var enabled in new[] { false, true })
            {
                AppSettings.SetShowPrayerNameInPrayerLanguage(enabled);
                var card = PrayerCardName.ForBundle("trisagion", selectedRite);
                Assert.Equal(expected, card.Title);
                Assert.Empty(card.InterfaceSubtitle);
            }
            var globalTitle = globalRite == "he" ? "טריסאגיון" : "קדישת";
            Assert.Equal(globalTitle, DesktopPrayerLibrary.Gallery().Single(item => item.Id == "trisagion").Title);
            Assert.Equal("מחרוזת הורדים", PrayerPackStore.InterfaceDisplayName("rosary", selectedRite));
        }
        finally
        {
            UiLanguageCatalog.UseLanguageForCurrentSession(oldUi);
            AppSettings.SetDefaultLanguageCode(oldDefault);
            AppSettings.SetShowPrayerNameInPrayerLanguage(oldNames);
            AppSettings.SetLanguageFallbackOrder(oldOrder);
        }
    }

    [Theory]
    [InlineData("he-IL", "he-x-gamliel", "he-x-gamliel")]
    [InlineData("iw-IL", "he", "he")]
    [InlineData("en", "he-x-gamliel", "en")]
    [InlineData("ar", "he", "ar")]
    [InlineData("he", "uk", "he")]
    public void OnlyHebrewInterfaceNamesFollowHebrewPrayerTraditions(string ui, string prayer, string expected) =>
        Assert.Equal(expected, PrayerCardName.InterfaceTitleLanguage(ui, prayer));
}
