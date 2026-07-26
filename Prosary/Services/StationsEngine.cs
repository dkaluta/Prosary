using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the opening prayer, the fourteen stations (each announced with the traditional
/// versicle/response before its meditation), and the closing prayer — ported from iOS's
/// <c>StubStationsEngine.swift</c>. Like <see cref="AngelusEngine"/>, the Stations aren't
/// user-configurable — there's no config to pass, just a language. Unlike the Rosary/Franciscan
/// Crown/Seven Sorrows/Divine Mercy Chaplet, there's no decade/bead math at all — every step
/// leaves Mystery/DecadeIndex/HailMaryIndexInDecade at their null defaults, same as
/// AngelusEngine.</summary>
public sealed class StationsEngine
{
    private static readonly string[] Ordinals =
    [
        "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
        "8th", "9th", "10th", "11th", "12th", "13th", "14th",
    ];

    public IReadOnlyList<RosaryStep> BuildSteps(string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var steps = new List<RosaryStep>
        {
            new("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"),
            new("Opening Prayer", null, Text(PrayerKey.StationsOpeningPrayer), ImageOverrideKey: "crucifix"),
        };

        foreach (var station in StationsCatalog.All)
        {
            var stationText = StationsTranslations.Get(languageCode, station.ImageKey);
            var ordinalLabel = $"{Ordinals[station.Order - 1]} Station";
            var body = $"V. {Text(PrayerKey.StationsVersicle)}\nR. {Text(PrayerKey.StationsResponse)}\n\n{stationText.Meditation}";

            steps.Add(new RosaryStep(stationText.Title, ordinalLabel, body, ImageOverrideKey: station.ImageKey));
        }

        steps.Add(new RosaryStep("Closing Prayer", null, Text(PrayerKey.StationsClosingPrayer), ImageOverrideKey: "crucifix"));

        return steps;
    }
}
