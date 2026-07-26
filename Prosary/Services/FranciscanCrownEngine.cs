using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the fixed sequence of steps for a Franciscan Crown session — ported from iOS's
/// <c>StubFranciscanCrownEngine.swift</c>. Like <see cref="AngelusEngine"/>, the Franciscan Crown
/// isn't user-configurable — there's no config to pass, just a language: Sign of the Cross, the
/// Seven Joys of Mary (each a decade of an Our Father + 10 Hail Marys), 2 additional Hail Marys
/// (for the 72 years traditionally attributed to Our Lady's life) + an Our Father (for the Pope's
/// intentions), the seasonal Marian antiphon, and a closing Sign of the Cross.</summary>
public sealed class FranciscanCrownEngine
{
    private static readonly string[] Ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"];

    private readonly LiturgicalCalendarService _calendar;

    public FranciscanCrownEngine(LiturgicalCalendarService calendar)
    {
        _calendar = calendar;
    }

    public IReadOnlyList<RosaryStep> BuildSteps(string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var steps = new List<RosaryStep>
        {
            new("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"),
        };

        var fruitLabel = Text(PrayerKey.FructusMysteriiLabel);

        for (var d = 0; d < FranciscanCrownCatalog.SevenJoys.Count; d++)
        {
            var imageKey = FranciscanCrownCatalog.SevenJoys[d];
            var joyText = MysteryTranslations.Get(languageCode, imageKey);
            var ordinalLabel = $"{Ordinals[d]} Joy";
            var decadeSubtitle = $"{ordinalLabel} — {joyText.Title}";

            steps.Add(new RosaryStep(
                joyText.Title, ordinalLabel, $"{joyText.Description}\n\n{fruitLabel}: {joyText.Fruit}",
                IsScripture: true, DecadeIndex: d, ImageOverrideKey: imageKey));

            steps.Add(new RosaryStep(
                "Our Father", decadeSubtitle, Text(PrayerKey.PaterNoster),
                DecadeIndex: d, ImageOverrideKey: imageKey));

            for (var h = 1; h <= 10; h++)
            {
                steps.Add(new RosaryStep(
                    $"Hail Mary ({h} of 10)", decadeSubtitle, Text(PrayerKey.AveMaria),
                    DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: imageKey));
            }
        }

        for (var h = 1; h <= 2; h++)
        {
            steps.Add(new RosaryStep(
                $"Hail Mary ({h} of 2)", "For the years of Our Lady's life", Text(PrayerKey.AveMaria),
                ImageOverrideKey: "madonna_and_child"));
        }

        steps.Add(new RosaryStep(
            "Our Father", "For the intentions of the Holy Father", Text(PrayerKey.PaterNoster),
            ImageOverrideKey: "our_father"));

        steps.Add(MarianAntiphonBuilder.BuildStep(_calendar.GetSeasonalMarianAntiphonForToday(), languageCode));

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"));

        return steps;
    }
}
