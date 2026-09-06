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

    [Fact]
    public void BasicCardPreferenceDoesNotChangeThePrayerBody()
    {
        var old = AppSettings.ShowPrayerNameInPrayerLanguage;
        try
        {
            var prayer = BasicPrayerCatalog.Prayer("ourFather")!;
            var body = BasicPrayerCatalog.Step(prayer, "he").Body;
            AppSettings.SetShowPrayerNameInPrayerLanguage(false);
            var interfaceName = PrayerPackStore.ResolveDisplayText(prayer.BundleId, UiLanguageCatalog.Current, prayer.TitleKey);
            Assert.Equal(interfaceName, PrayerCardName.ForBasicPrayer(prayer, "he").Title);
            AppSettings.SetShowPrayerNameInPrayerLanguage(true);
            Assert.Equal(PrayerPackStore.ResolveDisplayText(prayer.BundleId, "he", prayer.TitleKey),
                PrayerCardName.ForBasicPrayer(prayer, "he").Title);
            Assert.Equal(body, BasicPrayerCatalog.Step(prayer, "he").Body);
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
