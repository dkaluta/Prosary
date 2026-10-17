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
        var explanations = feast.LocalizedDescriptions("iw-IL");
        Assert.Contains(explanations.SelectMany(item => item.Sections), section => section.Id == "hymn");
        Assert.Contains(explanations.SelectMany(item => item.Sections), section => section.Id == "tradition");
        Assert.DoesNotContain(explanations, item => item.Text.Contains("נקודה להרהור:"));
        Assert.DoesNotContain(explanations.SelectMany(item => item.Sections), section => section.Id == "reflection");
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

    [Fact]
    public void ReflectionPartitionRequiresTheCompleteSameLanguageCopy()
    {
        const string fullText = "About:\nSource explanation.\n\nFirst reflection:\nFirst prompt.\n\nSecond reflection:\nSecond prompt.";
        var source = new FeastObservance("Fixture", "fixture", DescriptionByLanguage: new() { ["en"] = fullText }, Sections: [
            new("about", new() { ["en"] = "About" }, new() { ["en"] = "Source explanation." }),
            new("reflection", new() { ["en"] = "First reflection" }, new() { ["en"] = "First prompt." }),
            new("reflection", new() { ["en"] = "Second reflection" }, new() { ["en"] = "Second prompt." })]);
        foreach (var reflections in new Dictionary<string, string>?[] { null, new() { ["en"] = "Different prompt." },
            new() { ["en"] = "First prompt." }, new() { ["he"] = "First prompt. Second prompt." } })
        {
            var row = (source with { ReflectionByLanguage = reflections }).LocalizedDescription("en")!;
            Assert.Equal(fullText, row.Text);
            Assert.Equal(["about", "reflection", "reflection"], row.Sections.Select(section => section.Id));
        }
        var separated = (source with { ReflectionByLanguage = new() { ["en"] = " First prompt.\r\n\nSecond   prompt. " } }).LocalizedDescription("en")!;
        Assert.Equal("About:\nSource explanation.", separated.Text);
        Assert.Equal(["about"], separated.Sections.Select(section => section.Id));
        Assert.Equal(fullText, source.DescriptionByLanguage!["en"]);
    }
}
