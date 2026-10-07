using System.Text.Json;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class MissionCalendarTests
{
    [Fact]
    public void BundledReflectionsRetainRawSourceAndOnlyTheirPublishedLanguage()
    {
        using var source = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "feasts-mission-provisional.json")));
        var days = source.RootElement.GetProperty("days");
        Assert.Equal(365, days.EnumerateObject().Count());
        Assert.DoesNotContain(days.EnumerateObject(), row => row.Name.StartsWith("2027-"));
        var feast = days.GetProperty("2026-01-01").Deserialize<FeastDay>(new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        Assert.Equal(3, feast.Reflections("iw-IL").Count);
        Assert.Empty(feast.Reflections("en"));
        Assert.Empty(feast.Reflections("fr"));
        var observance = feast.Observances![0];
        Assert.Contains("נקודה לערעור:", observance.SourceDescriptionByLanguage!["he"]);
        Assert.Contains("נקודה להרהור:", observance.DescriptionByLanguage!["he"]);
        Assert.Equal("FREQ=YEARLY", observance.SourceRecurrence);
        Assert.Empty(observance.Categories!);
        Assert.Equal(observance.ReflectionByLanguage!["he"], observance.Sections!.Single(section => section.Id == "reflection").TextByLanguage["he"]);
        Assert.Contains("תקופת ניסיון", observance.Reflection("he")!.Credit);
    }

    [Fact]
    public void AReflectionDoesNotRequireBiographyOrBorrowForeignCredit()
    {
        var observance = new FeastObservance("Source", "identity", ReflectionByLanguage: new() { ["he"] = "מחשבה" },
            DescriptionCreditByLanguage: new() { ["en"] = "English credit" });
        Assert.Equal("מחשבה", observance.Reflection("he")?.Text);
        Assert.False(observance.Reflection("he")!.HasCredit);
        Assert.Null(observance.Reflection("en"));
        Assert.Null(observance.LocalizedDescription("he"));
    }
}
