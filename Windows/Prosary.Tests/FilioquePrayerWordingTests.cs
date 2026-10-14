using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class FilioquePrayerWordingTests : IClassFixture<PrayerPackLoaderFixture>
{
    public FilioquePrayerWordingTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב", "הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]")]
    [InlineData("הנובע מהאב ומהבן", "הנובע מהאב", "הנובע מהאב [ומהבן]")]
    [InlineData("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן", "אֲשֶׁר נֶאֱצַל מִן הָאָב", "אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]")]
    [InlineData("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק", "הַו דּמֶן אַבָא [ובא] ננפֶק")]
    [InlineData("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ")]
    [InlineData("qui ex Patre Filioque procedit", "qui ex Patre procedit", "qui ex Patre [Filioque] procedit")]
    [InlineData("що від Отця і Сина ісходить", "що від Отця ісходить", "що від Отця [і Сина] ісходить")]
    public void SourcePolicyChangesOnlyTheExactRecognizedClause(string included, string absent, string bracketed)
    {
        var source = "before ✠ " + included + " after";
        Assert.Equal("before ✠ " + absent + " after", FilioquePrayerWording.Apply("symbolumNicaenum", source, null, new(Filioque: "absent")).Text);
        Assert.Equal("before ✠ " + bracketed + " after", FilioquePrayerWording.Apply("symbolumNicaenum", source, null, new(Filioque: "bracketed")).Text);
        Assert.Equal(source, FilioquePrayerWording.Apply("symbolumNicaenum", "before ✠ " + bracketed + " after", null, new(Filioque: "unbracketed")).Text);
        Assert.Equal(absent, FilioquePrayerWording.Apply("symbolumNicaenum", absent, null, new(Filioque: "unbracketed")).Text);
    }

    [Fact]
    public void BothAramaicScriptsUseTheSameAuthoredPolicyAndRetainTheCross()
    {
        var rendered = FilioquePrayerWording.Apply("symbolumNicaenum", "הַו דּמֶן אַבָא ובא ננפֶק ✠",
            "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ ✠", new(false, "bracketed"));
        Assert.Equal("הַו דּמֶן אַבָא [ובא] ננפֶק ✠", rendered.Text);
        Assert.Equal("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ ✠", rendered.ReadingAid);
        Assert.Equal("אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]", FilioquePrayerWording.Apply("symbolumNicaenum",
            "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)", null, new(false, "bracketed")).Text);
    }

    [Theory]
    [InlineData("τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον")]
    [InlineData("An unfamiliar authored creed.")]
    public void AClauseIsNeverInventedForAnOmittingOrUnrecognizedSource(string text)
    {
        Assert.Equal(text, FilioquePrayerWording.Apply("symbolumNicaenum", text, null, new(Filioque: "unbracketed")).Text);
    }

    [Fact]
    public void UntaggedImportsKeepTheirAuthoredPunctuation()
    {
        const string source = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)";
        Assert.Equal(source, FilioquePrayerWording.Apply("symbolumNicaenum", source, source).Text);
        Assert.Equal(source, FilioquePrayerWording.Apply("anotherPrayer", source, source, new(Filioque: "bracketed")).Text);
    }

    [Theory]
    [InlineData("arc")]
    [InlineData("he-x-gamliel")]
    [InlineData("el")]
    [InlineData("uk")]
    public void EasternSourcesHideApostlesCreedAndKeepNiceneInDevotionSteps(string language)
    {
        var apostles = BasicPrayerCatalog.Prayer("creed")!;
        Assert.False(BasicPrayerCatalog.IsAvailable(apostles, language));
        Assert.DoesNotContain(BasicPrayerCatalog.Available(language), prayer => prayer.Id == "creed");
        Assert.Contains(BasicPrayerCatalog.Available(language), prayer => prayer.Id == "niceneCreed");
        Assert.Equal("", BasicPrayerCatalog.Step(apostles, language).Body);
        var nicene = PrayerPackStore.ResolveBodyText("rosary", language, "symbolumNicaenum");
        Assert.NotEmpty(nicene);
        Assert.Equal(nicene, PrayerPackStore.ResolveBodyText("rosary", language, "symbolumApostolorum"));
        Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", language, "symbolumNicaenumTitle"),
            PrayerPackStore.ResolveBodyText("rosary", language, "symbolumApostolorumTitle"));
    }

    [Fact]
    public void FallbackPolicyBelongsToTheActualWinningSource()
    {
        var previous = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["arc", "he", "la"]);
            Assert.Contains("[ובא]", PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum"));
            Assert.Contains("[ܘܒܐ]", PrayerPackStore.Transliteration("rosary", "en", "symbolumNicaenum")!);
            AppSettings.SetLanguageFallbackOrder(["he", "arc", "la"]);
            var hebrew = PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum");
            Assert.Contains("וּמֵהַבֵּן", hebrew);
            Assert.DoesNotContain("[", hebrew);
        }
        finally { AppSettings.SetLanguageFallbackOrder(previous); }
    }

    [Fact]
    public void SourcedUkrainianNiceneShowsItsFilioqueInSquareBrackets()
    {
        Assert.Contains("що від Отця [і Сина] ісходить", PrayerPackStore.ResolveBodyText("rosary", "uk", "symbolumNicaenum"));
    }
}
