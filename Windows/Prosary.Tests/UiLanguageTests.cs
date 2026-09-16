using System.Text.RegularExpressions;
using System.Xml.Linq;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class UiLanguageTests
{
    [Theory]
    [InlineData("", "de-DE,uk-UA,en-US", "uk")]
    [InlineData("", "de-DE,ja-JP", "en")]
    [InlineData("ar", "en-US", "ar")]
    [InlineData("fil-PH", "he-IL", "tl")]
    [InlineData("iw-IL", "en-US", "he")]
    [InlineData("la", "fr-CA,en-US", "fr")]
    public void AppLanguageResolvesAnExplicitSupportedChoiceOrTheWindowsPreferenceList(
        string preference, string windowsLanguages, string expected)
    {
        Assert.Equal(expected, UiLanguageCatalog.Resolve(preference, windowsLanguages.Split(',')));
    }

    [Fact]
    public void AppLanguagePickerHasEveryInterfaceLanguageAndNoPrayerOnlyLanguages()
    {
        var options = new SettingsViewModel(initialAudioCacheBytes: 0).AppLanguageOptions;
        Assert.Equal(new[] { "", "ar", "en", "fr", "he", "it", "ru", "tl", "uk" },
            options.Select(option => option.Tag).Order());
        Assert.Equal("System Default", options[0].Label);
    }

    [Fact]
    public void SavedAppLanguageWaitsForRelaunchAndKeepsExplicitPrayerAndBibleChoices()
    {
        var previousPreference = AppSettings.InterfaceLanguageCode;
        var previousCurrent = UiLanguageCatalog.Current;
        var previousPrayer = AppSettings.PrayerLanguageCode;
        var previousEdition = AppSettings.ReadingsEditionId;
        var previousBasic = AppSettings.BasicPrayersLanguageCode;
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("en");
            AppSettings.SetDefaultLanguageCode("");
            AppSettings.SetReadingsEditionId("explicit-edition");
            AppSettings.SetBasicPrayersLanguageCode("arc");
            var savedPrayer = new Prayer { LanguageCode = "he-x-gamliel" };
            var inheritedPrayer = new Prayer { LanguageCode = "" };
            AppSettings.SetInterfaceLanguageCode("fil-PH");
            Assert.Equal("tl", AppSettings.InterfaceLanguageCode);
            Assert.Equal("en", AppSettings.DefaultLanguageCode);
            Assert.Equal("en", inheritedPrayer.ResolvedLanguageCode);

            // The next launch activates the saved choice for both interface and inheritance.
            UiLanguageCatalog.UseLanguageForCurrentSession(
                UiLanguageCatalog.Resolve(AppSettings.InterfaceLanguageCode, ["en-US"]));
            Assert.Equal("tl", UiLanguageCatalog.Current);
            Assert.Equal("tl", AppSettings.DefaultLanguageCode);
            Assert.Equal("tl", inheritedPrayer.ResolvedLanguageCode);
            Assert.Equal("", inheritedPrayer.LanguageCode);
            Assert.Equal("he-x-gamliel", savedPrayer.LanguageCode);
            Assert.Equal("he-x-gamliel", savedPrayer.ResolvedLanguageCode);
            Assert.Equal("arc", AppSettings.BasicPrayersLanguageCode);
            Assert.Equal("explicit-edition", AppSettings.ReadingsEditionId);

            AppSettings.SetDefaultLanguageCode("arc");
            AppSettings.SetInterfaceLanguageCode("he");
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            Assert.Equal("he", UiLanguageCatalog.Current);
            Assert.Equal("arc", AppSettings.DefaultLanguageCode);
            Assert.Equal("arc", inheritedPrayer.ResolvedLanguageCode);
            Assert.Equal("he-x-gamliel", savedPrayer.ResolvedLanguageCode);
            Assert.Equal("explicit-edition", AppSettings.ReadingsEditionId);

            AppSettings.SetDefaultLanguageCode("");
            AppSettings.SetInterfaceLanguageCode("");
            UiLanguageCatalog.UseLanguageForCurrentSession(
                UiLanguageCatalog.Resolve(AppSettings.InterfaceLanguageCode, ["de-DE", "ar-SA"]));
            Assert.Equal("", AppSettings.InterfaceLanguageCode);
            Assert.Equal("ar", AppSettings.DefaultLanguageCode);
            Assert.True(UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current));
        }
        finally
        {
            AppSettings.SetInterfaceLanguageCode(previousPreference);
            UiLanguageCatalog.UseLanguageForCurrentSession(previousCurrent);
            AppSettings.SetDefaultLanguageCode(previousPrayer);
            AppSettings.SetReadingsEditionId(previousEdition);
            AppSettings.SetBasicPrayersLanguageCode(previousBasic);
        }
    }

    [Fact]
    public void GlobalPrayerPickerSupportsAramaicAndCanReturnToFollowingTheApp()
    {
        var previousCurrent = UiLanguageCatalog.Current;
        var previousPrayer = AppSettings.PrayerLanguageCode;
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("en");
            AppSettings.SetDefaultLanguageCode("arc");
            var settings = new SettingsViewModel(initialAudioCacheBytes: 0);
            Assert.Equal("arc", settings.SelectedLanguage.Code);
            Assert.True(settings.ShowsAramaicSignOfCrossPicker);
            Assert.Contains(settings.LanguageOptions, option => option.Code == "la");
            Assert.Equal("App Language (English)", settings.LanguageOptions[0].NativeName);

            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            Assert.Equal("arc", AppSettings.DefaultLanguageCode);
            settings.SelectedLanguage = settings.LanguageOptions.Single(option => option.Code == "he");
            Assert.True(settings.ShowsRitePicker);
            settings.SelectedRite = settings.RiteOptions.Single(option => option.Code == "he-x-gamliel");
            Assert.Equal("he-x-gamliel", AppSettings.DefaultLanguageCode);

            settings.SelectedLanguage = settings.LanguageOptions[0];
            Assert.Equal("", AppSettings.PrayerLanguageCode);
            Assert.Equal("he", AppSettings.DefaultLanguageCode);
            Assert.False(settings.ShowsRitePicker);
            Assert.False(settings.ShowsAramaicSignOfCrossPicker);
            UiLanguageCatalog.UseLanguageForCurrentSession("uk");
            Assert.Equal("uk", AppSettings.DefaultLanguageCode);
        }
        finally
        {
            UiLanguageCatalog.UseLanguageForCurrentSession(previousCurrent);
            AppSettings.SetDefaultLanguageCode(previousPrayer);
        }
    }

    [Fact]
    public void AppLanguageLabelAndSharedDefaultExplanationShipInEveryInterface()
    {
        foreach (var language in UiLanguageCatalog.All)
        {
            var resources = Resources(UiLanguageCatalog.ResourceTag(language.Code));
            Assert.False(string.IsNullOrWhiteSpace(resources["SetAppLanguageUsage.Text"]));
            Assert.False(string.IsNullOrWhiteSpace(resources["SetAppLanguageFooter.Text"]));
            Assert.Equal(resources["SetAppLanguageCombo.Header"] + " ({0})",
                resources["language_app_parenthesized"]);
        }
        Assert.Equal("שפת היישומון", Resources("he")["SetAppLanguageCombo.Header"]);
    }

    [Fact]
    public void HebrewHasOneLanguageChoiceAndPreservesASeparateTradition()
    {
        Assert.Single(LanguageCatalog.PickerOptions.Where(language => language.Code.StartsWith("he")));
        Assert.Equal("עברית", LanguageCatalog.Resolve("he-x-gamliel").NativeName);
        Assert.Equal("ܐܪܡܐܝܬ / ארמית", LanguageCatalog.Resolve("arc").NativeName);
        Assert.Equal("he", LanguageCatalog.PickerLanguageCode("he-x-gamliel"));
        Assert.Equal("he-x-gamliel", LanguageCatalog.SelectingLanguage("he", "he-x-gamliel"));
        Assert.Equal("", LanguageCatalog.SelectingLanguage("", "he-x-gamliel"));
        Assert.Equal("en", LanguageCatalog.SelectingLanguage("en", "he-x-gamliel"));
    }

    [Theory]
    [InlineData("he-x-gamliel", "he")]
    [InlineData("he", "he-x-gamliel")]
    public void FallbackEditorRoundTripsHebrewTraditionsWithAramaicBetweenThem(string first, string second)
    {
        var previous = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder([]);
            var rows = LanguageCatalog.FallbackOptions;
            Assert.Equal(LanguageCatalog.All.Count, rows.Count);
            Assert.NotEqual(rows.Single(row => row.Code == "he").NativeName,
                rows.Single(row => row.Code == "he-x-gamliel").NativeName);
            foreach (var tradition in LanguageCatalog.Rites("he"))
                Assert.EndsWith(tradition.NativeName, rows.Single(row => row.Code == tradition.Code).NativeName);

            var leadingCodes = new[] { first, "arc", second };
            var editedRows = leadingCodes.Select(code => rows.Single(row => row.Code == code))
                .Concat(rows.Where(row => !leadingCodes.Contains(row.Code))).ToArray();
            var savedCodes = editedRows.Select(row => row.Code).ToArray();
            AppSettings.SetLanguageFallbackOrder(savedCodes);

            Assert.Equal(savedCodes, AppSettings.LanguageFallbackOrder);
            Assert.Equal(savedCodes, LanguageCatalog.FallbackOptions.Select(row => row.Code));
            Assert.Equal(leadingCodes, LanguageCatalog.FallbackOptions.Take(3).Select(row => row.Code));
            Assert.Single(LanguageCatalog.PickerOptions, row => row.Code.StartsWith("he"));
        }
        finally { AppSettings.SetLanguageFallbackOrder(previous); }
    }

    [Theory]
    [InlineData("fil-PH", "tl", false)]
    [InlineData("tl-PH", "tl", false)]
    [InlineData("ar-EG", "ar", true)]
    [InlineData("he-x-gamliel", "he", true)]
    [InlineData("iw-IL", "he", true)]
    [InlineData("ru-RU", "ru", false)]
    [InlineData("fr-CA", "fr", false)]
    [InlineData("it-IT", "it", false)]
    [InlineData("uk-UA", "uk", false)]
    [InlineData("de", "en", false)]
    public void SupportedTagsResolveTheirSharedContentCodeAndDirection(string tag, string expected, bool rtl)
    {
        Assert.Equal(expected, UiLanguageCatalog.Normalize(tag));
        Assert.Equal(rtl, UiLanguageCatalog.IsRightToLeft(tag));
        Assert.Equal("fil", UiLanguageCatalog.ResourceTag("tl"));
    }

    [Fact]
    public void TodayFollowsTheInterfaceAndIgnoresTheRetiredOverride()
    {
        var previousPrayerLanguage = AppSettings.PrayerLanguageCode;
        var previousTodayLanguage = AppSettings.TodayLanguageCode;
        try
        {
            AppSettings.SetTodayLanguageCode("");
            AppSettings.SetDefaultLanguageCode("he");
            Assert.Equal("fr", UiLanguageCatalog.ResolveToday(AppSettings.TodayLanguageCode, "fr-FR"));
            AppSettings.SetTodayLanguageCode("ar");
            AppSettings.SetDefaultLanguageCode("it");
            Assert.Equal("fr", UiLanguageCatalog.ResolveToday(AppSettings.TodayLanguageCode, "fr-FR"));
            Assert.Equal("it", AppSettings.DefaultLanguageCode);
        }
        finally
        {
            AppSettings.SetDefaultLanguageCode(previousPrayerLanguage);
            AppSettings.SetTodayLanguageCode(previousTodayLanguage);
        }
    }

    [Theory]
    [InlineData("ar", "الزمن العادي")]
    [InlineData("ru", "Рядового времени")]
    [InlineData("tl", "Karaniwang Panahon")]
    [InlineData("fil-PH", "Karaniwang Panahon")]
    [InlineData("fr-CA", "temps ordinaire")]
    [InlineData("it", "Tempo Ordinario")]
    public void TodayLocalizesTheWeekAndSeasonInEachAddedLanguage(string language, string season)
    {
        var previous = TodayInfoStore.SelectedCalendarId;
        try
        {
            TodayInfoStore.SelectedCalendarId = "roman";
            var day = TodayInfoStore.LiturgicalDay(new DateOnly(2026, 8, 31));
            Assert.Contains(season, day.Localized(language));
            Assert.DoesNotContain("Monday", day.Localized(language));
            Assert.DoesNotContain("Week", day.Localized(language));
        }
        finally { TodayInfoStore.SelectedCalendarId = previous; }
    }

    [Fact]
    public void LocalizedDataUsesRegionalTagsAndSkipsBlankEntries()
    {
        var titles = new Dictionary<string, string> { ["fr"] = "Titre", ["fr-CA"] = " ", ["tl"] = "Pamagat" };
        var feast = new FeastDay("Source title", "Feast", titles);
        Assert.Equal("Titre", feast.LocalizedTitle("fr-CA"));
        Assert.Equal("Pamagat", feast.LocalizedTitle("fil-PH"));
        Assert.Equal("Source title", feast.LocalizedTitle("it"));
        var intention = new PopeIntention("Title", "Source text", titles,
            new Dictionary<string, string> { ["it"] = "Testo", ["ru"] = "" });
        Assert.Equal("Testo", intention.LocalizedText("it-IT"));
        Assert.Equal("Source text", intention.LocalizedText("ru"));
        var reading = new ReadingCitation("reading", "Source short", "Source full",
            ShortByLanguage: new() { ["tl"] = "Jn 3" }, FullByLanguage: new() { ["tl"] = "Juan 3:16" });
        Assert.Equal("Jn 3", reading.LocalizedShort("fil-PH"));
        Assert.Equal("Juan 3:16", reading.LocalizedFull("fil-PH"));
    }

    [Fact]
    public void AllInterfacesShipTheSameNonemptyResourcesAndFormattingArguments()
    {
        var english = Resources("en-US");
        foreach (var language in new[] { "he", "ar", "ru", "fil", "fr", "it", "uk" })
        {
            var localized = Resources(language);
            Assert.Equal(english.Keys.Order(), localized.Keys.Order());
            foreach (var (key, text) in localized)
            {
                Assert.False(string.IsNullOrWhiteSpace(text), $"{language}/{key} is empty");
                Assert.Equal(Arguments(english[key]), Arguments(text));
            }
            Assert.NotEqual(english["HomeTodayReadings.Text"], localized["HomeTodayReadings.Text"]);
            Assert.NotEqual(english["home_pope_intention"], localized["home_pope_intention"]);
            Assert.NotEqual(english["home_today_rank_solemnity"], localized["home_today_rank_solemnity"]);
            Assert.NotEqual(english["BtnBack.Content"], localized["BtnBack.Content"]);
        }
    }

    [Fact]
    public void UkrainianUsesItsOwnLocalizedResources()
    {
        var ukrainian = Resources("uk");
        Assert.Equal("uk", UiLanguageCatalog.Normalize("uk-UA"));
        Assert.Equal("Налаштування", ukrainian["SetTitle.Text"]);
        Assert.Equal("Основні молитви", ukrainian["BasicPrayersTitle.Text"]);
        Assert.Equal("Молитва", ukrainian["NavPray.Content"]);
        Assert.Equal("День {0} із {1}", ukrainian["multi_day_day_of"]);
        Assert.NotEqual(Resources("ru")["SetTitle.Text"], ukrainian["SetTitle.Text"]);
    }

    [Fact]
    public void FrenchAndItalianAreAvailableForPrayerSelection()
    {
        Assert.Equal("fr", LanguageCatalog.Resolve("fr").Code);
        Assert.Equal("it", LanguageCatalog.Resolve("it").Code);
        Assert.Equal(new[] { "fr", "it" }, LanguageCatalog.AvailableOptions(["fr", "it"]).Select(l => l.Code));
    }

    [Fact]
    public void NewPrayerLanguagesPrecedeTheExistingFinalLatinFallback()
    {
        var original = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["he", "en", "la"]);
            Assert.Equal("la", LanguageCatalog.FallbackOrder.Last());
            Assert.True(LanguageCatalog.FallbackOrder.ToList().IndexOf("fr") < LanguageCatalog.FallbackOrder.ToList().IndexOf("la"));
            AppSettings.SetLanguageFallbackOrder(["la", "he"]);
            Assert.Equal("la", LanguageCatalog.FallbackOrder.First());
        }
        finally
        {
            AppSettings.SetLanguageFallbackOrder(original);
        }
    }

    private static Dictionary<string, string> Resources(string language) =>
        XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Strings", language, "Resources.resw"))
            .Root!.Elements("data").ToDictionary(e => e.Attribute("name")!.Value, e => e.Element("value")!.Value);

    private static IEnumerable<string> Arguments(string value) =>
        Regex.Matches(value, @"\{\d+(?:[^}]*)\}").Select(match => match.Value).Order();
}
