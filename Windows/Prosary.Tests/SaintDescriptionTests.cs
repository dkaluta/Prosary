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
            Assert.Empty(today.SaintDescriptions);
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
