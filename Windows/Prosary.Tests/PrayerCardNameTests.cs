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
}
