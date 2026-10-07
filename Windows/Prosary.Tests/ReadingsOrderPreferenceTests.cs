using System.Text.Json;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class ReadingsOrderPreferenceTests
{
    private static ReadingCitation[] Citations() =>
    [
        new("reading", "Short reading", "First Reading 1:1–3", FullByLanguage: new() { ["he"] = "קריאה מלאה ראשונה" }, SourceGroup: "Day Mass") { ReadingDatasetId = "roman" },
        new("psalm", "Short psalm", "Psalm 1:1–4", FullByLanguage: new() { ["he"] = "מזמור מלא" }, SourceGroup: "Day Mass") { ReadingDatasetId = "roman" },
        new("gospel", "Short gospel", "John 1:1–5", FullByLanguage: new() { ["he"] = "בשורה מלאה" }, SourceGroup: "Day Mass") { ReadingDatasetId = "roman" },
    ];

    [Fact]
    public void GospelFirstIsOnlyAProjectionAndRetainsEveryOriginalAppointmentIdentity()
    {
        var source = Citations();
        var bytes = JsonSerializer.Serialize(source);
        Assert.Same(source, ReadingCitation.DisplayOrder(source, false));
        var displayed = ReadingCitation.DisplayOrder(source, true);
        Assert.Equal(new[] { "gospel", "psalm", "reading" }, displayed.Select(citation => citation.Type));
        Assert.Same(source[2], displayed[0]);
        Assert.Same(source[0], displayed[2]);
        Assert.Equal(bytes, JsonSerializer.Serialize(source));
        Assert.All(displayed, citation => Assert.Equal("roman", citation.ReadingDatasetId));
        Assert.Empty(ReadingCitation.DisplayOrder([], true));
    }

    [Fact]
    public void NotificationCaptionsStayFullAndUseTheSameOptionalDisplayOrder()
    {
        var source = Citations();
        Assert.Equal("קריאה מלאה ראשונה; מזמור מלא; בשורה מלאה", TodayReminderScheduler.ReadingsBody(source, "he"));
        Assert.Equal("בשורה מלאה; מזמור מלא; קריאה מלאה ראשונה", TodayReminderScheduler.ReadingsBody(source, "he", true));
        Assert.DoesNotContain("Short", TodayReminderScheduler.ReadingsBody(source, "en", true));
        Assert.Contains("John 1:1–5", TodayReminderScheduler.ReadingsBody(source, "en", true));
    }

    [Fact]
    public void ReorderingDailyReadingsRetainsExpansionWhileTorahStaysInSourceOrder()
    {
        var previous = AppSettings.ReverseReadingsOrder;
        try
        {
            AppSettings.SetReverseReadingsOrder(false);
            var source = Citations();
            var today = new HomeViewModel(new EmptyPresets(), new LiturgicalCalendarService())
            {
                TodayReadings = source,
                TodayTorahPortion = new TorahPortion("2026-10-10", "Fixture", null, false,
                    [new("torah", "First", "Genesis 1:1"), new("torah", "Second", "Exodus 1:1")], null),
            };
            var store = new ReadingsTextStore(() => """{"schemaVersion":1,"editions":[],"passages":{}}""");
            var reader = new DesktopReadingsViewModel(store);
            reader.Refresh(today);
            var gospel = reader.Daily[2];
            gospel.ScriptOverride = "Syrc";
            gospel.IsExpanded = true;
            reader.Daily[0].IsExpanded = false;
            var torah = reader.Torah.ToArray();
            AppSettings.SetReverseReadingsOrder(true);
            reader.Refresh(today);
            Assert.Same(gospel, reader.Daily[0]);
            Assert.Equal("Syrc", reader.Daily[0].ScriptOverride);
            Assert.Equal(gospel.Citation, reader.Daily[0].Citation);
            Assert.Equal(gospel.ContextKey, reader.Daily[0].ContextKey);
            Assert.True(reader.Daily[0].IsExpanded);
            Assert.False(reader.Daily[2].IsExpanded);
            Assert.Equal("Day Mass", reader.Daily[0].SourceGroup);
            Assert.Null(reader.Daily[2].SourceGroup);
            Assert.Same(torah[0], reader.Torah[0]);
            Assert.Same(torah[1], reader.Torah[1]);
            Assert.Same(source, today.TodayReadings);
        }
        finally { AppSettings.SetReverseReadingsOrder(previous); }
    }

    [Fact]
    public async Task GroupHeadingChangesRetainCachedPassageAndTheChosenReadingScript()
    {
        var previousOrder = AppSettings.ReverseReadingsOrder;
        var previousEdition = AppSettings.ReadingsEditionId;
        try
        {
            AppSettings.SetReverseReadingsOrder(false);
            AppSettings.SetReadingsEditionId("fixture-arc");
            var today = new HomeViewModel(new EmptyPresets(), new LiturgicalCalendarService()) { TodayReadings = Citations() };
            var libraryRequests = 0;
            var store = new ReadingsTextStore(() => """
                {"schemaVersion":1,"editions":[{"id":"fixture-arc","languageCode":"arc","name":"Fixture",
                "attribution":"Fixture credit","sourceURL":"https://example.test",
                "textScript":"Hebr","transliteratedTextScript":"Syrc"}],
                "passageBooks":{"daily|John 1:1–5":{"fixture-arc":"JHN"}},
                "passages":{"daily|John 1:1–5":{"fixture-arc":[{"chapter":1,"verse":1,"text":"אבג","transliteratedText":"ܐܒܓ"}]}}}
                """, bibleStoreFactory: () => { libraryRequests++; return null; });
            var reader = new DesktopReadingsViewModel(store);
            reader.Refresh(today);
            var gospel = reader.Daily[2];
            gospel.IsExpanded = true;
            for (var attempt = 0; attempt < 100 && !gospel.HasPassage; attempt++) await Task.Delay(10);
            Assert.True(gospel.HasPassage);
            Assert.True(gospel.HasScriptToggle);
            gospel.ScriptOverride = "Syrc";
            var text = gospel.PassageText;
            var chapters = gospel.Chapters;
            Assert.Contains("ܐܒܓ", text);
            Assert.Equal(1, libraryRequests);
            Assert.Null(gospel.SourceGroup);

            AppSettings.SetReverseReadingsOrder(true);
            reader.Refresh(today);
            Assert.Same(gospel, reader.Daily[0]);
            Assert.Equal("Day Mass", gospel.SourceGroup);
            Assert.True(gospel.IsExpanded);
            Assert.Equal("Syrc", gospel.ScriptOverride);
            Assert.Equal(text, gospel.PassageText);
            Assert.Same(chapters, gospel.Chapters);
            Assert.Equal(1, libraryRequests);
            AppSettings.SetReverseReadingsOrder(false);
            reader.Refresh(today);
            Assert.Same(gospel, reader.Daily[2]);
            Assert.Null(gospel.SourceGroup);
            Assert.Equal("Syrc", gospel.ScriptOverride);
            Assert.Equal(1, libraryRequests);
        }
        finally
        {
            AppSettings.SetReadingsEditionId(previousEdition);
            AppSettings.SetReverseReadingsOrder(previousOrder);
        }
    }

    [Fact]
    public void AContextualSettingsRefreshReadsTheSameReminderWithoutChangingOrSchedulingIt()
    {
        var previousEnabled = AppSettings.ReadingsReminderEnabled;
        var previousMinutes = AppSettings.ReadingsReminderMinutes;
        var previousOrder = AppSettings.ReverseReadingsOrder;
        var notifications = 0;
        void Changed() => notifications++;
        try
        {
            AppSettings.SetReadingsReminderEnabled(false);
            AppSettings.SetReadingsReminderMinutes(540);
            AppSettings.SetReverseReadingsOrder(false);
            var settings = new SettingsViewModel(0);
            AppSettings.SetReadingsReminderEnabled(true);
            AppSettings.SetReadingsReminderMinutes(615);
            AppSettings.SetReverseReadingsOrder(true);
            AppSettings.ReadingsOrderChanged += Changed;
            settings.SynchronizeReadingPreferences();
            Assert.True(settings.ReadingsReminderEnabled);
            Assert.Equal(TimeSpan.FromMinutes(615), settings.ReadingsReminderTime);
            Assert.True(settings.ReverseReadingsOrder);
            Assert.Equal(0, notifications);
            Assert.Equal(615, AppSettings.ReadingsReminderMinutes);
        }
        finally
        {
            AppSettings.ReadingsOrderChanged -= Changed;
            AppSettings.SetReadingsReminderEnabled(previousEnabled);
            AppSettings.SetReadingsReminderMinutes(previousMinutes);
            AppSettings.SetReverseReadingsOrder(previousOrder);
        }
    }

    private sealed class EmptyPresets : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);
        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;
        public Task<bool> UpdateIfPresentAsync(Prayer prayer) => Task.FromResult(false);
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
