using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the fixed sequence of steps for a Seven Sorrows session — ported from iOS's
/// <c>StubSevenSorrowsEngine.swift</c>. Like <see cref="FranciscanCrownEngine"/>, the Seven Sorrows
/// isn't user-configurable — there's no config to pass, just a language: Sign of the Cross, the
/// Seven Sorrows of Mary (each a decade of an Our Father + 7 Hail Marys — 7, not 10, per
/// traditional practice), 3 additional Hail Marys (for Our Lady's tears), a fixed closing
/// versicle/response/collect (unlike the Rosary/Franciscan Crown, this isn't a user choice — the
/// Seven Sorrows always closes the same way), and a closing Sign of the Cross.</summary>
public sealed class SevenSorrowsEngine
{
    private static readonly string[] Ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th"];

    public IReadOnlyList<RosaryStep> BuildSteps(string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var steps = new List<RosaryStep>
        {
            new("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"),
        };

        var fruitLabel = Text(PrayerKey.FructusMysteriiLabel);

        for (var d = 0; d < SevenSorrowsCatalog.SevenSorrows.Count; d++)
        {
            var imageKey = SevenSorrowsCatalog.SevenSorrows[d];
            var sorrowText = MysteryTranslations.Get(languageCode, imageKey);
            var ordinalLabel = $"{Ordinals[d]} Sorrow";
            var decadeSubtitle = $"{ordinalLabel} — {sorrowText.Title}";

            steps.Add(new RosaryStep(
                sorrowText.Title, ordinalLabel, $"{sorrowText.Description}\n\n{fruitLabel}: {sorrowText.Fruit}",
                IsScripture: d != SevenSorrowsCatalog.MeetingOnTheWayIndex, DecadeIndex: d, ImageOverrideKey: imageKey));

            steps.Add(new RosaryStep(
                "Our Father", decadeSubtitle, Text(PrayerKey.PaterNoster),
                DecadeIndex: d, ImageOverrideKey: imageKey));

            for (var h = 1; h <= 7; h++)
            {
                steps.Add(new RosaryStep(
                    $"Hail Mary ({h} of 7)", decadeSubtitle, Text(PrayerKey.AveMaria),
                    DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: imageKey));
            }
        }

        for (var h = 1; h <= 3; h++)
        {
            steps.Add(new RosaryStep(
                $"Hail Mary ({h} of 3)", "For the tears of Our Lady", Text(PrayerKey.AveMaria),
                ImageOverrideKey: "madonna_and_child"));
        }

        steps.Add(new RosaryStep(
            "Our Lady of Sorrows", null,
            $"V. {Text(PrayerKey.SevenSorrowsVersicle)}\nR. {Text(PrayerKey.SevenSorrowsResponse)}\n\n{Text(PrayerKey.SevenSorrowsCollect)}",
            ImageOverrideKey: "madonna_and_child"));

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"));

        return steps;
    }
}
