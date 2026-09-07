using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class UkrainianPrayerContentTests : IClassFixture<PrayerPackLoaderFixture>, IDisposable
{
    private readonly string[] _savedFallback;
    public UkrainianPrayerContentTests(PrayerPackLoaderFixture _)
    {
        _savedFallback = AppSettings.LanguageFallbackOrder.ToArray();
        AppSettings.SetLanguageFallbackOrder(["en", "he", "la"]);
    }
    public void Dispose() => AppSettings.SetLanguageFallbackOrder(_savedFallback);

    private static IReadOnlyList<RosaryStep> Steps(string bundle, string? variant = null) =>
        PrayerEngine.BuildCustomDevotionSteps(bundle, "uk", false, MarianAntiphonOption.SalveRegina,
            variant, null, rosaryOptions: null, todaysGroup: MysteryGroup.Joyful, dayIndex: 0, isLent: false);

    [Fact]
    public void AllBasicPrayersUseTheSourcedUkrainianTitleAndBody()
    {
        string[] titles = ["Знак хреста", "Отче наш", "Радуйся, Маріє", "Слава Отцю", "Апостольський символ віри", "Святий Боже"];
        foreach (var (prayer, title) in BasicPrayerCatalog.All.Zip(titles))
        {
            var step = BasicPrayerCatalog.Step(prayer, "uk");
            Assert.Equal(title, step.Title);
            Assert.Equal(PrayerTypography.Script.Cyrillic, PrayerTypography.ScriptOf(step.Body));
            Assert.NotEqual(BasicPrayerCatalog.Step(prayer, "en").Body, step.Body);
        }
    }

    [Fact]
    public void UkrainianDevotionsRenderTextInsteadOfUnresolvedKeys()
    {
        foreach (var bundle in new[] { "divineMercyChaplet", "angelus", "oAntiphons", "sevenSorrows" })
        {
            var rendered = Steps(bundle);
            Assert.NotEmpty(rendered);
            Assert.Contains(rendered, step => PrayerTypography.ScriptOf(step.Body) == PrayerTypography.Script.Cyrillic);
            foreach (var step in rendered)
            {
                Assert.DoesNotMatch("^[a-z][A-Za-z0-9]*$", step.Title);
                Assert.DoesNotMatch("^[a-z][A-Za-z0-9]*$", step.Body);
            }
        }
    }

    [Fact]
    public void ScripturalStationsUseUkrainianAndMissingMeditationsFollowTheSelectedFallback()
    {
        var scriptural = Steps("stationsOfTheCross", "scriptural");
        Assert.Equal("Ісус у Гетсиманському саду", scriptural[2].Title);
        Assert.StartsWith("І приходять на врочище Гетсиман", scriptural[2].Body);
        Assert.Contains("Марко 14:32–36", scriptural[2].Body);
        Assert.True(scriptural[2].IsScripture);
        var english = PrayerPackStore.ResolveBodyText("stationsOfTheCross", "en", "station01Body");
        Assert.NotEqual("station01Body", english);
        Assert.Equal(english, PrayerPackStore.ResolveBodyText("stationsOfTheCross", "uk", "station01Body"));
        Assert.Contains(english, Steps("stationsOfTheCross", "traditional")[2].Body);
    }
}
