using System.Text.Json;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Persistence;
using Xunit;

namespace Prosary.Tests;

public class RosaryCustomOptionsTests
{
    [Theory]
    [InlineData(null, "true", null, null, true)]
    [InlineData(null, null, "true", null, true)]
    [InlineData(null, null, null, "true", true)]
    [InlineData(null, "false", null, null, false)]
    [InlineData("true", "false", "false", "false", false)]
    [InlineData("true", "false", "false", null, true)]
    [InlineData("false", "false", "false", "false", false)]
    [InlineData("true", "invalid", "false", "false", true)]
    [InlineData("invalid", "TRUE", null, null, false)]
    public void OldGroupStringsMergeWithoutMutatingStoredOptions(
        string? combined, string? pope, string? bishop, string? departed, bool expected)
    {
        var original = new Dictionary<string, string> { ["unrelated"] = "keep" };
        void Set(string key, string? value)
        {
            if (value is not null) original[key] = value;
        }
        Set("closingIntentions", combined);
        Set("closingPopeIntention", pope);
        Set("closingBishopIntention", bishop);
        Set("closingDepartedIntention", departed);
        var snapshot = original.ToDictionary(pair => pair.Key, pair => pair.Value);

        var result = RosaryCustomOptions.Normalize("rosary", original);

        Assert.Equal(expected ? "true" : "false", result["closingIntentions"]);
        Assert.Equal("keep", result["unrelated"]);
        Assert.All(RosaryCustomOptions.LegacyClosingKeys, key => Assert.False(result.ContainsKey(key)));
        Assert.Equal(snapshot.OrderBy(pair => pair.Key), original.OrderBy(pair => pair.Key));
    }

    [Fact]
    public void ModernOptionsAndOtherBundlesKeepTheirOwnKeysAndDefaults()
    {
        Assert.Empty(RosaryCustomOptions.Normalize("rosary", null));
        var modern = new Dictionary<string, string> { ["openingFatimaPrayer"] = "true" };
        Assert.Equal(modern.OrderBy(pair => pair.Key),
            RosaryCustomOptions.Normalize("rosary", modern).OrderBy(pair => pair.Key));
        var foreign = new Dictionary<string, string>
        {
            ["closingPopeIntention"] = "true",
            ["closingIntentions"] = "false",
        };
        Assert.Equal(foreign.OrderBy(pair => pair.Key),
            RosaryCustomOptions.Normalize("anotherRosary", foreign).OrderBy(pair => pair.Key));
    }

    [Fact]
    public void OlderPackEditorShowsOneCombinedControlInTheFormerGroupsPosition()
    {
        CustomDevotionOption Toggle(string key) => new(key, CustomDevotionOption.OptionKind.Toggle, key,
            Default: JsonSerializer.SerializeToElement(false));
        CustomDevotionOption[] oldOptions =
        [
            Toggle("before"), Toggle("closingPopeIntention"), Toggle("closingBishopIntention"),
            Toggle("closingDepartedIntention"), Toggle("after"),
        ];

        var updated = RosaryCustomOptions.EditorOptions("rosary", oldOptions);
        Assert.Equal(new[] { "before", "closingIntentions", "after" }, updated.Select(option => option.Key));
        Assert.Equal(CustomDevotionOption.OptionKind.Toggle, updated[1].Kind);
        Assert.Equal("false", updated[1].DefaultValue);
        Assert.NotEmpty(updated[1].LocalizedName);
        Assert.Same(oldOptions, RosaryCustomOptions.EditorOptions("anotherRosary", oldOptions));

        var combined = Toggle("closingIntentions");
        var mixed = RosaryCustomOptions.EditorOptions("rosary", [.. oldOptions, combined]);
        Assert.Equal(new[] { "before", "after", "closingIntentions" }, mixed.Select(option => option.Key));
        Assert.Same(combined, mixed.Last());
    }

    [Fact]
    public void CustomClosingSignatureUsesCombinedBehaviorAndInvalidatesTheFormerIntroductionPositions()
    {
        var modern = new Dictionary<string, string> { ["closingIntentions"] = "true" };
        var partial = new Dictionary<string, string> { ["closingBishopIntention"] = "true" };
        var signature = PrayerRunSignatures.Custom("rosary", null, 0, modern);
        Assert.Equal(signature, PrayerRunSignatures.Custom("rosary", null, 0, partial));
        Assert.Equal("custom|rosary||0|closingIntentions=true|closing-v2:1,1,1", signature);
        Assert.NotEqual("custom|rosary||0|closingIntentions=true", signature);

        var allOff = new Dictionary<string, string>
        {
            ["closingIntentions"] = "true", ["closingPopeIntention"] = "false",
            ["closingBishopIntention"] = "false", ["closingDepartedIntention"] = "false",
        };
        Assert.Equal("custom|rosary||0|closingIntentions=false",
            PrayerRunSignatures.Custom("rosary", null, 0, allOff));
        Assert.Equal("custom|rosary||0|", PrayerRunSignatures.Custom("rosary", null, 0));
    }

    [Theory]
    [InlineData(null, null, false)]
    [InlineData(null, "true", true)]
    [InlineData("true", "true", true)]
    [InlineData("false", "true", false)]
    [InlineData("true", "false", false)]
    [InlineData("false", "false", false)]
    public void CustomOpeningSignatureOnlyInvalidatesAnIncludedOpeningFatima(
        string? opening, string? fatima, bool changed)
    {
        var options = new Dictionary<string, string> { ["closingIntentions"] = "true" };
        if (opening is not null) options["openingPrayers"] = opening;
        if (fatima is not null) options["openingFatimaPrayer"] = fatima;
        var signature = PrayerRunSignatures.Custom("rosary", "traditional", 2, options);
        Assert.Equal(changed, signature.EndsWith("|opening-fatima-v2", StringComparison.Ordinal));
        Assert.EndsWith(changed ? "|closing-v2:1,1,1|opening-fatima-v2" : "|closing-v2:1,1,1", signature);

        var raw = string.Join("|", options.OrderBy(pair => pair.Key).Select(pair => $"{pair.Key}={pair.Value}"));
        Assert.Equal($"custom|anotherRosary|traditional|2|{raw}",
            PrayerRunSignatures.Custom("anotherRosary", "traditional", 2, options));
    }
}
