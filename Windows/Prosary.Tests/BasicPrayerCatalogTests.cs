using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class BasicPrayerCatalogTests : IClassFixture<PrayerPackLoaderFixture>
{
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
