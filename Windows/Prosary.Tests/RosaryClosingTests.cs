using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class RosaryClosingTests : IClassFixture<PrayerPackLoaderFixture>
{
    public RosaryClosingTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public void ClosingOptionsProduceExactlyOneCollectAfterTheOptionalLitany(bool litany, bool collect)
    {
        foreach (var language in new[] { "en", "he", "he-x-gamliel", "ar", "ru", "tl", "fr", "it", "uk", "la", "es", "el", "arc" })
        foreach (var antiphon in new[] { MarianAntiphonOption.None, MarianAntiphonOption.SalveRegina, MarianAntiphonOption.ReginaCaeli })
        {
            var options = new RosaryOptions
            {
                IncludeLitanyOfLoreto = litany, IncludeRosaryCollect = collect,
                IncludeClosingIntentions = true, IncludeStMichaelPrayer = true,
                MarianAntiphon = antiphon,
            };
            var steps = PrayerEngine.BuildCustomDevotionSteps("rosary", language, false, antiphon,
                optionOverrides: PrayerEngine.RosaryOptionValues(options), rosaryOptions: options).ToList();
            var collectBody = PrayerPackStore.ResolveBodyText("rosary", language, "rosaryCollect");
            Assert.Equal(litany || collect ? 1 : 0, steps.Count(step => step.Body == collectBody));
            if (litany || collect)
            {
                Assert.Equal(collectBody, steps[^2].Body);
                Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", language, "rosaryCollectTitle"), steps[^2].Title);
            }
            Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", language, "signumCrucis"), steps[^1].Body);
            Assert.All(steps.Where(step => step.IsAntiphon), step =>
            {
                Assert.DoesNotContain(PrayerTranslations.Get(language, PrayerKey.CollectaStandard), step.Body);
                Assert.DoesNotContain(PrayerTranslations.Get(language, PrayerKey.CollectaPaschale), step.Body);
            });
            var litanyEntries = PrayerPackStore.Definition("litanyOfLoreto")!.ResolvedSteps("afterRosary").Steps;
            var litanyLanguage = PrayerPackStore.EffectiveLanguage("litanyOfLoreto", language);
            var litanyBodies = litanyEntries.Take(litanyEntries.Count - 1)
                .Select(entry => PrayerPackStore.ResolveBodyText("litanyOfLoreto", litanyLanguage, entry.BodyKey!)).ToArray();
            if (litany)
            {
                var embedded = steps.Skip(steps.Count - litanyBodies.Length - 2).Take(litanyBodies.Length).ToArray();
                Assert.Equal(litanyBodies, embedded.Select(step => step.Body));
                Assert.Equal(PrayerPackStore.ResolveBodyText("litanyOfLoreto", litanyLanguage, litanyEntries[0].TitleKey!), embedded[0].Title);
            }
            else
                Assert.DoesNotContain(steps, step => step.Body == litanyBodies[0]);
        }
    }

    [Fact]
    public void GenericRosaryForcesTheCollectAndStandaloneLitanyKeepsItsOwnCollect()
    {
        var engine = new PrayerEngine(new LiturgicalCalendarService());
        var generic = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = "rosary", LanguageCode = "en",
            CustomOptions = new() { ["litanyOfLoreto"] = "true", ["rosaryCollect"] = "false" } };
        var steps = engine.BuildSteps(generic);
        Assert.Equal(PrayerPackStore.ResolveBodyText("rosary", "en", "rosaryCollect"), steps[^2].Body);
        var standalone = generic with { CustomDevotionId = "litanyOfLoreto", VariantId = "afterRosary" };
        Assert.Equal(PrayerPackStore.ResolveBodyText("litanyOfLoreto", "en", "collectStandard"), engine.BuildSteps(standalone)[^1].Body);
    }
}
