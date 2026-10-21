using System.Xml.Linq;
using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class RosaryOptionLabelsTests : IClassFixture<PrayerPackLoaderFixture>
{
    public RosaryOptionLabelsTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData("he", "he-x-gamliel", "אבינו שבשמים", "שמחי מרים", "כבוד לאב", "אני מאמין")]
    [InlineData("he-x-gamliel", "he", "תפילת האדון", "שלום לך מרים", "השבח לאב", "מאמינים של ניקאה")]
    public void HebrewCaptionsUseTheSelectedRiteDespiteOppositeDefaultsAndFallbacks(
        string rite, string global, string father, string hailMary, string glory, string creed)
    {
        var oldUi = UiLanguageCatalog.Current;
        var oldDefault = AppSettings.PrayerLanguageCode;
        var oldFallback = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            AppSettings.SetDefaultLanguageCode(global);
            AppSettings.SetLanguageFallbackOrder([global, "en", rite, "la"]);
            foreach (var picker in new[] { false, true })
            {
                var opening = RosaryOptionLabels.OpeningPrayers(rite, picker);
                Assert.Contains(father, opening);
                Assert.Contains(hailMary, opening);
                Assert.Contains(glory, RosaryOptionLabels.OpeningFatima(rite, picker));
                Assert.Equal(creed, RosaryOptionLabels.Creed(rite, picker));
            }
            Assert.Contains(hailMary, RosaryOptionLabels.PresenterHint(rite));
            Assert.Contains(glory, RosaryOptionLabels.PresenterHint(rite));
            Assert.Equal(RosaryOptionLabels.OpeningPrayers(rite), RosaryOptionLabels.CustomOption("openingPrayers", rite));
            Assert.Equal(RosaryOptionLabels.OpeningFatima(rite), RosaryOptionLabels.CustomOption("openingFatimaPrayer", rite));
            Assert.Equal(creed, RosaryOptionLabels.CustomOption("apostlesCreed", rite));
            var antiphon = PrayerPackStore.Options("rosary").Single(option => option.Key == "antiphon");
            var cases = RosaryOptionLabels.WithAntiphonTitles(antiphon, rite).Cases!;
            foreach (var choice in cases.Where(choice => choice.Id is not "none" and not "seasonal"))
                Assert.Equal(PrayerPackStore.ResolveDisplayText("rosary", rite, choice.Id + "Title"), choice.LocalizedName);
            Assert.Equal(antiphon.Cases!.Single(choice => choice.Id == "none").LocalizedName,
                cases.Single(choice => choice.Id == "none").LocalizedName);
            if (rite == "he")
            {
                Assert.DoesNotContain("שלום לך", RosaryOptionLabels.PresenterHint(rite));
                Assert.DoesNotContain("שבח לאב", RosaryOptionLabels.OpeningFatima(rite));
            }
            else
            {
                Assert.DoesNotContain("שמחי מרים", RosaryOptionLabels.PresenterHint(rite));
                Assert.DoesNotContain("כבוד לאב", RosaryOptionLabels.OpeningFatima(rite));
            }
            AppSettings.SetDefaultLanguageCode(rite);
            Assert.Equal(RosaryOptionLabels.OpeningPrayers(rite), RosaryOptionLabels.OpeningPrayers(""));
        }
        finally
        {
            UiLanguageCatalog.UseLanguageForCurrentSession(oldUi);
            AppSettings.SetDefaultLanguageCode(oldDefault);
            AppSettings.SetLanguageFallbackOrder(oldFallback);
        }
    }

    [Fact]
    public void OtherInterfacesKeepTheirCaptionsAndNonHebrewPrayersHaveNeutralHebrewCaptions()
    {
        var oldUi = UiLanguageCatalog.Current;
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("en");
            foreach (var rite in new[] { "he", "he-x-gamliel" })
            {
                Assert.Equal(Loc.Tr("EdOpeningPrayers.Text", "Opening Our Father & 3 Hail Marys"), RosaryOptionLabels.OpeningPrayers(rite));
                Assert.Equal(Loc.Tr("PickerOpeningFatima.Text", "Fatima Prayer after the opening Glory Be"), RosaryOptionLabels.OpeningFatima(rite, picker: true));
                Assert.Null(RosaryOptionLabels.CustomOption("openingPrayers", rite));
            }
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            foreach (var language in new[] { "en", "la", "arc" })
            {
                Assert.Equal("תפילות פתיחה", RosaryOptionLabels.OpeningPrayers(language));
                Assert.Equal("תפילת פאטימה הנוספת בפתיחה", RosaryOptionLabels.OpeningFatima(language));
                Assert.DoesNotContain("שלום לך", RosaryOptionLabels.PresenterHint(language));
                Assert.DoesNotContain("שמחי מרים", RosaryOptionLabels.PresenterHint(language));
            }
        }
        finally { UiLanguageCatalog.UseLanguageForCurrentSession(oldUi); }
    }

    [Fact]
    public void CaptionTemplatesShipTheSameArgumentsInEveryInterfaceLanguage()
    {
        var argumentCounts = new Dictionary<string, int>
        {
            ["rosary_opening_prayers_format"] = 2,
            ["rosary_opening_fatima_format"] = 2,
            ["rosary_fatima_each_decade_format"] = 1,
            ["rosary_presenter_hint_format"] = 2,
            ["rosary_final_sign_format"] = 1,
        };
        foreach (var language in UiLanguageCatalog.All)
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Strings", UiLanguageCatalog.ResourceTag(language.Code), "Resources.resw");
            var resources = XDocument.Load(path).Root!.Elements("data")
                .ToDictionary(item => item.Attribute("name")!.Value, item => item.Element("value")!.Value);
            foreach (var (key, count) in argumentCounts)
            {
                Assert.False(string.IsNullOrWhiteSpace(resources[key]));
                for (var argument = 0; argument < count; argument++) Assert.Contains($"{{{argument}}}", resources[key]);
                var formatted = string.Format(resources[key], Enumerable.Repeat<object>("Prayer", count).ToArray());
                Assert.DoesNotContain("{", formatted);
            }
        }
    }
}
