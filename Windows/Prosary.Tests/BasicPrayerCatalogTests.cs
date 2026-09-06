using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class BasicPrayerCatalogTests : IClassFixture<PrayerPackLoaderFixture>
{
    [Fact]
    public void HomePinsShareManualOrderWithDevotionsWithoutReorderingThePrayerList()
    {
        var prayer = BasicPrayerCatalog.Prayer("ourFather")!;
        Assert.Equal("basic:ourFather", prayer.HomeCardId);
        var cards = new[] { "rosary", "basic:ourFather", "jesusPrayer", "basic:holyGod" };
        Assert.Equal(new[] { "basic:holyGod", "rosary", "basic:ourFather", "jesusPrayer" },
            HomeOrder.Apply(cards, id => id, ["basic:holyGod", "rosary", "basic:ourFather"]));
        var previous = AppSettings.FavoriteBasicPrayersFirst;
        try
        {
            AppSettings.SetFavoriteBasicPrayersFirst(true);
            Assert.Equal(BasicPrayerCatalog.All, BasicPrayersOrder.ApplyFavorites(BasicPrayerCatalog.All));
        }
        finally { AppSettings.SetFavoriteBasicPrayersFirst(previous); }
    }

    public BasicPrayerCatalogTests(PrayerPackLoaderFixture _)
    {
    }

    [Fact]
    public void ExplicitLanguageOverridesDefaultAndSentinelKeepsFollowingIt()
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        try
        {
            var prayer = BasicPrayerCatalog.Prayer("ourFather")!;
            AppSettings.SetDefaultLanguageCode("he");

            var english = BasicPrayerCatalog.Step(prayer, "en");
            Assert.Equal("Our Father", english.Title);
            Assert.Contains("Our Father", english.Body);
            Assert.Equal("he", AppSettings.DefaultLanguageCode);

            var followingDefault = BasicPrayerCatalog.Step(prayer, LanguageCatalog.DefaultSentinel);
            Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", "he", "paterNoster"), followingDefault.Body);

            AppSettings.SetDefaultLanguageCode("arc");
            followingDefault = BasicPrayerCatalog.Step(prayer, LanguageCatalog.DefaultSentinel);
            Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", "arc", "paterNoster"), followingDefault.Body);
            Assert.Equal(PrayerPackStore.Transliteration("rosary", "arc", "paterNoster"), followingDefault.TransliteratedBody);
            Assert.NotNull(followingDefault.TransliteratedBody);
            Assert.Equal(english.Body, BasicPrayerCatalog.Step(prayer, "en").Body);
        }
        finally
        {
            AppSettings.SetDefaultLanguageCode(previousDefault);
        }
    }
}
