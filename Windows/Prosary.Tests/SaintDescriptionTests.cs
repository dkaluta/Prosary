using System.Text.Json;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class SaintDescriptionTests
{
    [Theory]
    [InlineData("Saint Matthew", " Saint\nMatthew ")]
    [InlineData("חג מתי", "חַג   מַתִּי")]
    public void RepeatedParentHeadingHidesOnlyTheDescriptionTitle(string title, string parentTitle)
    {
        var source = new SaintDescription("source-identity", title, "Sourced prose", "Source credit",
            new Uri("https://example.test/source"), "Text source");
        var displayed = source.UnderHeading(parentTitle);
        Assert.False(displayed.ShowsTitle);
        Assert.True(source.ShowsTitle);
        Assert.Equal(source.Title, displayed.Title);
        Assert.Equal(source.Text, displayed.Text);
        Assert.Equal(source.Identity, displayed.Identity);
        Assert.Equal(source.Credit, displayed.Credit);
        Assert.Equal(source.SourceUri, displayed.SourceUri);
    }

    [Fact]
    public void DistinctSaintHeadingsRemainVisibleUnderACombinedFeastTitle()
    {
        var feast = new FeastDay("Saint Matthew; Saint Luke", "Feast", Observances:
        [
            new("Saint Matthew", "matthew", DescriptionByLanguage: new() { ["en"] = "Matthew prose" }),
            new("Saint Luke", "luke", DescriptionByLanguage: new() { ["en"] = "Luke prose" }),
        ]);
        var descriptions = feast.LocalizedDescriptions("en", feast.LocalizedTitle("en"));
        Assert.Equal(2, descriptions.Count);
        Assert.All(descriptions, description => Assert.True(description.ShowsTitle));
        Assert.Equal(new[] { "Saint Matthew", "Saint Luke" }, descriptions.Select(description => description.Title));
    }

    [Fact]
    public void SourceSectionsKeepEachRitesOwnIdsTitlesOrderAndParagraphs()
    {
        var mission = new FeastObservance("Saint", "mission", DescriptionByLanguage: new()
        {
            ["he"] = "מסורת:\nפסקה ראשונה\n\nפסקה שנייה\n\nתפילה:\nתפילה מקורית",
        }, Sections:
        [
            new("tradition", new() { ["he"] = "מסורת" }, new() { ["he"] = "פסקה ראשונה\n\nפסקה שנייה" }),
            new("prayer", new() { ["he"] = "תפילה" }, new() { ["he"] = "תפילה מקורית" }),
        ]);
        var roman = new FeastObservance("Saint", "roman", DescriptionByLanguage: new()
        {
            ["en"] = "History:\nSource history\n\nCollect:\nSource prayer",
        }, Sections:
        [
            new("local-history", new() { ["en"] = "History" }, new() { ["en"] = "Source history" }),
            new("collect", new() { ["en"] = "Collect" }, new() { ["en"] = "Source prayer" }),
        ]);
        var missionText = mission.LocalizedDescription("iw-IL")!;
        var romanText = roman.LocalizedDescription("en")!;
        Assert.True(missionText.ShowsSections);
        Assert.False(missionText.ShowsUnsectionedText);
        Assert.Equal(new[] { "tradition", "prayer" }, missionText.Sections.Select(section => section.Id));
        Assert.Equal("פסקה ראשונה\n\nפסקה שנייה", missionText.Sections[0].Text);
        Assert.Equal(new[] { "local-history", "collect" }, romanText.Sections.Select(section => section.Id));
        Assert.Equal(new[] { "History", "Collect" }, romanText.Sections.Select(section => section.Title));
        Assert.Null(mission.LocalizedDescription("en"));
        Assert.Null(roman.LocalizedDescription("he"));
        Assert.Null(roman.LocalizedDescription("unknown"));
    }

    [Fact]
    public void SectionOnlyDescriptionsUseExactLocaleAliasesWithoutBorrowingATitleOrBody()
    {
        var observance = new FeastObservance("Saint", "identity", Sections:
        [
            new("local", new() { ["tl"] = "Kasaysayan" }, new() { ["tl"] = "Tekstong pinagmulan" }),
            new("foreign-heading", new() { ["en"] = "English" }, new() { ["tl"] = "Teksto" }),
            new("foreign-body", new() { ["tl"] = "Pamagat" }, new() { ["en"] = "English" }),
        ]);
        var description = observance.LocalizedDescription("fil-PH")!;
        var section = Assert.Single(description.Sections);
        Assert.Equal("local", section.Id);
        Assert.Equal("Kasaysayan", section.Title);
        Assert.Equal("Tekstong pinagmulan", section.Text);
        Assert.Equal("Kasaysayan:\nTekstong pinagmulan", description.Text);
        Assert.False(description.ShowsUnsectionedText);
        Assert.Null(observance.LocalizedDescription("fr"));
        Assert.Null(observance.LocalizedDescription("unknown"));
    }

    [Fact]
    public void IncompleteSectionsKeepAllSourceProseAndReflectionsStayIndependent()
    {
        const string fullText = "History:\nHistory prose\n\nAdditional source prose";
        var observance = new FeastObservance("Saint", "identity",
            DescriptionByLanguage: new() { ["en"] = fullText }, Sections:
            [new("history", new() { ["en"] = "History" }, new() { ["en"] = "History prose" })],
            ReflectionByLanguage: new() { ["en"] = "Reflection prose" });
        var description = observance.LocalizedDescription("en")!;
        Assert.Empty(description.Sections);
        Assert.True(description.ShowsUnsectionedText);
        Assert.Equal(fullText, description.Text);
        var reflection = observance.Reflection("en")!;
        Assert.Empty(reflection.Sections);
        Assert.True(reflection.ShowsUnsectionedText);
        Assert.Equal("Reflection prose", reflection.Text);
    }

    [Fact]
    public void OptionalObservanceMetadataDecodesWithoutChangingLegacyFeastTitles()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        var oldFeast = JsonSerializer.Deserialize<FeastDay>("""{"title":"Feast","rank":"Feast"}""", options)!;
        Assert.Empty(oldFeast.LocalizedDescriptions("en"));
        var feast = JsonSerializer.Deserialize<FeastDay>("""
            {"title":"Source title","rank":"Feast","observances":[
              {"title":"Saint","identity":"identity","titleByLanguage":{"he":"כותרת"},
               "descriptionByLanguage":{"he":"טקסט\nמקורי"},
               "descriptionCreditByLanguage":{"he":"Urtotho (2026)"},
               "descriptionSourceByLanguage":{"he":"https://example.test/source"}},
              {"title":"Another saint","identity":"other","descriptionByLanguage":{"en":"English only"}}
            ]}
            """, options)!;
        var description = Assert.Single(feast.LocalizedDescriptions("iw-IL"));
        Assert.Equal("identity", description.Identity);
        Assert.Equal("כותרת", description.Title);
        Assert.Equal("טקסט\nמקורי", description.Text);
        Assert.Equal("Urtotho (2026)", description.Credit);
        Assert.Equal("https://example.test/source", description.SourceUri?.AbsoluteUri);
        Assert.Empty(feast.LocalizedDescriptions("fr"));
        Assert.Equal("Source title", feast.Title);
    }

    [Fact]
    public void DescriptionSourceAndCreditNeverBorrowAnotherLanguage()
    {
        var observance = new FeastObservance("Saint", "identity",
            DescriptionByLanguage: new() { ["tl"] = "Teksto", ["he"] = " " },
            DescriptionSourceByLanguage: new() { ["en"] = "https://example.test/en" },
            DescriptionCreditByLanguage: new() { ["en"] = "English credit" });
        var description = observance.LocalizedDescription("fil-PH")!;
        Assert.Equal("Teksto", description.Text);
        Assert.False(description.HasSource);
        Assert.False(description.HasCredit);
        Assert.Null(observance.LocalizedDescription("he"));
        Assert.Null(observance.LocalizedDescription("en"));
        Assert.Null((observance with { DescriptionSourceByLanguage = new() { ["tl"] = "file:///private/source" } })
            .LocalizedDescription("tl")!.SourceUri);
    }

    [Fact]
    public void DisclosureResetsForDateCalendarLanguageAndVisibilityButNotTimerRefresh()
    {
        var language = UiLanguageCatalog.Current;
        var calendar = TodayInfoStore.SelectedCalendarId;
        var showFeast = AppSettings.ShowTodayFeast;
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            AppSettings.SetShowTodayFeast(true);
            TodayInfoStore.SelectedCalendarId = "syriac";
            var today = new HomeViewModel(new EmptyPresetStore(), new LiturgicalCalendarService());
            today.SelectedTodayDate = new DateTimeOffset(2026, 10, 1, 0, 0, 0, TimeSpan.Zero);
            Assert.False(today.IsSaintDescriptionsExpanded);
            today.IsSaintDescriptionsExpanded = true;
            today.RefreshToday();
            Assert.True(today.IsSaintDescriptionsExpanded);
            today.SelectedTodayDate = today.SelectedTodayDate.Value.AddDays(1);
            Assert.False(today.IsSaintDescriptionsExpanded);
            today.IsSaintDescriptionsExpanded = true;
            UiLanguageCatalog.UseLanguageForCurrentSession("fr");
            today.RefreshToday();
            Assert.False(today.IsSaintDescriptionsExpanded);
            today.IsSaintDescriptionsExpanded = true;
            TodayInfoStore.SelectedCalendarId = "roman";
            today.RefreshToday();
            Assert.False(today.IsSaintDescriptionsExpanded);
            // This fixed date has sourced French Guardian Angels prose. A calendar
            // change resets disclosure state without suppressing available text.
            var french = Assert.Single(today.SaintDescriptions);
            Assert.Equal("The Holy Guardian Angels", french.Identity);
            Assert.Equal("Saints anges gardiens", french.Title);
            Assert.True(french.HasSource);
            Assert.True(french.HasCredit);
            today.IsSaintDescriptionsExpanded = true;
            AppSettings.SetShowTodayFeast(false);
            today.RefreshToday();
            Assert.False(today.IsSaintDescriptionsExpanded);
            Assert.False(today.ShowsSaintDescriptions);
        }
        finally
        {
            UiLanguageCatalog.UseLanguageForCurrentSession(language);
            TodayInfoStore.SelectedCalendarId = calendar;
            AppSettings.SetShowTodayFeast(showFeast);
        }
    }

    private sealed class EmptyPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);
        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;
        public Task<bool> UpdateIfPresentAsync(Prayer prayer) => Task.FromResult(false);
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
