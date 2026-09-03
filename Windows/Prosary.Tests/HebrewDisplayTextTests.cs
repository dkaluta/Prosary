using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class HebrewDisplayTextTests
{
    [Fact]
    public void WithoutMarksRemovesHebrewPointsButPreservesPunctuation()
    {
        Assert.Equal("שלום־לך׃", HebrewDisplayText.WithoutMarks("שָׁלוֹם־לָךְ׃"));
        Assert.Equal("יי", HebrewDisplayText.WithoutMarks("י\uFB1Eי"));
    }

    [Fact]
    public void RosaryStepUnpointsOnlyDisplayChrome()
    {
        const string pointed = "שָׁלוֹם לָךְ";
        var step = new RosaryStep(pointed, pointed, pointed, Acclamation: pointed,
            TransliteratedBody: pointed);

        Assert.Equal("שלום לך", step.Title);
        Assert.Equal("שלום לך", step.Subtitle);
        Assert.Equal(pointed, step.Body);
        Assert.Equal(pointed, step.Acclamation);
        Assert.Equal(pointed, step.TransliteratedBody);

        // Record `with` expressions are used when the engine supplies a decade subtitle after
        // constructing a step. Its init accessor must enforce the same display-only boundary.
        var copied = step with { Title = pointed, Subtitle = pointed };
        Assert.Equal("שלום לך", copied.Title);
        Assert.Equal("שלום לך", copied.Subtitle);
    }

    [Fact]
    public void DisplayLookupLeavesCanonicalPrayerTablePointed()
    {
        var canonical = PrayerTranslations.Get("he", PrayerKey.SalveReginaTitle);

        Assert.Contains('\u05B8', canonical);
        Assert.Equal("שלום עליך מלכה", PrayerTranslations.GetDisplay("he", PrayerKey.SalveReginaTitle));
        Assert.Equal(canonical, PrayerTranslations.Get("he", PrayerKey.SalveReginaTitle));
    }
}
