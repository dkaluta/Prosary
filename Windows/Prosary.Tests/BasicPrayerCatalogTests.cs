using Prosary.Localization;
using Prosary.Models;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class BasicPrayerCatalogTests : IClassFixture<PrayerPackLoaderFixture>
{
    [Fact]
    public void RepositoryLanguageNamesKeepGenericHebrewSeparateFromTraditions()
    {
        Assert.Equal("עברית", LanguageCatalog.ContentLanguageName("he"));
        Assert.Equal("עברית", LanguageCatalog.ContentLanguageName("iw"));
        var mission = LanguageCatalog.Rites("he").Single(rite => rite.Code == "he-x-gamliel");
        Assert.Equal($"עברית — {mission.NativeName}", LanguageCatalog.ContentLanguageName("he-x-gamliel"));
        Assert.NotEqual(LanguageCatalog.ContentLanguageName("he"), LanguageCatalog.FallbackOptions.Single(option => option.Code == "he").NativeName);
    }

    [Fact]
    public void PinControlUpdatesItsStateAndKeepsThePrayerAvailableAfterRemoval()
    {
        var oldIds = AppSettings.FavoriteBasicPrayerIds.ToHashSet();
        try
        {
            foreach (var id in oldIds) AppSettings.ToggleFavoriteBasicPrayer(id);
            var list = new BasicPrayersViewModel();
            list.Load();
            var prayer = list.Rows.Single(row => row.Id == "ourFather");
            Assert.False(prayer.IsPinned);
            Assert.Equal("Pin to Pray", prayer.PinActionLabel);
            list.TogglePinCommand.Execute(prayer);
            var pinned = list.Rows.Single(row => row.Id == prayer.Id);
            Assert.True(pinned.IsPinned);
            Assert.Equal("Remove from Pray", pinned.PinActionLabel);
            Assert.Contains(prayer.Id, AppSettings.FavoriteBasicPrayerIds);
            Assert.Equal("basicPrayerPin-ourFather", pinned.PinAutomationId);
            list.TogglePinCommand.Execute(pinned);
            Assert.False(list.Rows.Single(row => row.Id == prayer.Id).IsPinned);
            Assert.DoesNotContain(prayer.Id, AppSettings.FavoriteBasicPrayerIds);
            Assert.NotNull(BasicPrayerCatalog.Prayer(prayer.Id));
        }
        finally
        {
            foreach (var id in AppSettings.FavoriteBasicPrayerIds.ToArray()) AppSettings.ToggleFavoriteBasicPrayer(id);
            foreach (var id in oldIds) AppSettings.ToggleFavoriteBasicPrayer(id);
        }
    }

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

    [Theory]
    [InlineData("salveRegina", PrayerKey.SalveReginaTitle, PrayerKey.SalveRegina)]
    [InlineData("almaRedemptorisMater", PrayerKey.AlmaRedemptorisMaterTitle, PrayerKey.AlmaRedemptorisMater)]
    [InlineData("aveReginaCaelorum", PrayerKey.AveReginaCaelorumTitle, PrayerKey.AveReginaCaelorum)]
    [InlineData("reginaCaeli", PrayerKey.ReginaCaeliTitle, PrayerKey.ReginaCaeli)]
    public void MarianAntiphonsRemainDistinctStandalonePrayersInEveryLanguage(string id, string titleKey, string bodyKey)
    {
        var prayer = Assert.Single(BasicPrayerCatalog.All.Where(prayer => prayer.Id == id));
        Assert.Equal($"basic:{id}", prayer.HomeCardId);
        foreach (var language in new[] { "la", "en", "he", "he-x-gamliel", "arc", "ar", "el", "es", "ru", "tl", "fr", "it", "uk" })
        {
            var step = BasicPrayerCatalog.Step(prayer, language);
            Assert.Equal(PrayerTranslations.GetDisplay(language, titleKey), step.Title);
            // Exact equality excludes the versicle/response/collect added by the Rosary flow.
            Assert.Equal(PrayerTranslations.Get(language, bodyKey), step.Body);
            Assert.False(string.IsNullOrWhiteSpace(step.Body));
            Assert.Equal("madonna_and_child", step.ImageOverrideKey);
            Assert.Equal(PrayerPackStore.Transliteration("rosary", language, prayer.BodyKey), step.TransliteratedBody);
        }
    }

    [Fact]
    public void BasicPrayerNamesKeepEverySelectedLanguageWithOptionalInterfaceSubtitles()
    {
        var previous = AppSettings.ShowPrayerNameInPrayerLanguage;
        var titles = new Dictionary<string, string>
        {
            ["la"] = "Pater Noster", ["en"] = "Our Father", ["he"] = "אבינו שבשמים",
            ["he-x-gamliel"] = "תפילת האדון", ["arc"] = "צלותא מרניתא", ["ar"] = "الأبانا",
            ["el"] = "Πάτερ ημών", ["es"] = "Padre nuestro", ["ru"] = "Отче наш",
            ["tl"] = "Ama Namin", ["fr"] = "Notre Père", ["it"] = "Padre nostro",
            ["uk"] = "Отче наш",
        };
        try
        {
            foreach (var (language, expectedOurFather) in titles)
            foreach (var prayer in BasicPrayerCatalog.All)
            foreach (var enabled in new[] { false, true })
            {
                AppSettings.SetShowPrayerNameInPrayerLanguage(enabled);
                var name = PrayerCardName.ForBasicPrayer(prayer, language, "he");
                var prayerTitle = BasicPrayerCatalog.Step(prayer, language).Title;
                var interfaceTitle = BasicPrayerCatalog.Step(prayer, "he").Title;
                Assert.Equal(prayerTitle, name.Title);
                Assert.Equal(enabled && prayerTitle != interfaceTitle ? interfaceTitle : "", name.InterfaceSubtitle);
                if (prayer.Id == "ourFather") Assert.Equal(expectedOurFather, name.Title);
            }
        }
        finally { AppSettings.SetShowPrayerNameInPrayerLanguage(previous); }
    }

    [Fact]
    public void BasicPrayerListFollowsDefaultLanguageChangesWhileKeepingAnExplicitOverride()
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        var previousBasic = AppSettings.BasicPrayersLanguageCode;
        var previousNames = AppSettings.ShowPrayerNameInPrayerLanguage;
        try
        {
            AppSettings.SetBasicPrayersLanguageCode(LanguageCatalog.DefaultSentinel);
            AppSettings.SetShowPrayerNameInPrayerLanguage(false);
            var list = new BasicPrayersViewModel();
            foreach (var (language, expected) in new[] { ("he-x-gamliel", "תפילת האדון"), ("arc", "צלותא מרניתא") })
            {
                AppSettings.SetDefaultLanguageCode(language);
                list.Load();
                Assert.Equal(expected, list.Rows.Single(row => row.Id == "ourFather").Title);
                Assert.False(list.Rows.Single(row => row.Id == "ourFather").HasInterfaceSubtitle);
            }
            list.SelectLanguage("en");
            AppSettings.SetDefaultLanguageCode("he-x-gamliel");
            list.Load();
            Assert.Equal("Our Father", list.Rows.Single(row => row.Id == "ourFather").Title);
            Assert.Equal("en", AppSettings.BasicPrayersLanguageCode);
        }
        finally
        {
            AppSettings.SetDefaultLanguageCode(previousDefault);
            AppSettings.SetBasicPrayersLanguageCode(previousBasic);
            AppSettings.SetShowPrayerNameInPrayerLanguage(previousNames);
        }
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
