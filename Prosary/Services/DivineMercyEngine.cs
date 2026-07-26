using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the fixed sequence of steps for a Divine Mercy Chaplet session — ported from
/// iOS's <c>StubDivineMercyEngine.swift</c>. Like <see cref="FranciscanCrownEngine"/>/
/// <see cref="SevenSorrowsEngine"/>, the Divine Mercy Chaplet isn't user-configurable — there's
/// no config to pass, just a language: Sign of the Cross, Our Father, Hail Mary, the Apostles'
/// Creed (the traditional opening, reusing existing PrayerKeys — nothing new needed there), 5
/// decades each of one offering ("Eternal Father, I offer You...") at the Our-Father-bead
/// position and 10 petitions ("For the sake of His sorrowful Passion...") at the Hail-Mary-bead
/// positions — the same two lines every decade, unlike the Rosary/Franciscan Crown/Seven Sorrows
/// — closing with the acclamation ("Holy God, Holy Mighty One, Holy Immortal One...") prayed
/// three times, and a closing Sign of the Cross. Every step reuses the single
/// <c>divine_mercy_image</c> illustration, the same reuse pattern the Angelus uses for
/// <c>joyful_01_annunciation</c>.</summary>
public sealed class DivineMercyEngine
{
    private const string ImageKey = "divine_mercy_image";
    private static readonly string[] Ordinals = ["1st", "2nd", "3rd", "4th", "5th"];

    public IReadOnlyList<RosaryStep> BuildSteps(string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var steps = new List<RosaryStep>
        {
            new("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: ImageKey),
            new("Our Father", null, Text(PrayerKey.PaterNoster), ImageOverrideKey: ImageKey),
            new("Hail Mary", null, Text(PrayerKey.AveMaria), ImageOverrideKey: ImageKey),
            new("The Apostles' Creed", null, Text(PrayerKey.SymbolumApostolorum), ImageOverrideKey: ImageKey),
        };

        for (var d = 0; d < 5; d++)
        {
            var decadeSubtitle = $"{Ordinals[d]} Decade";

            steps.Add(new RosaryStep(
                "Eternal Father, I Offer You...", decadeSubtitle, Text(PrayerKey.DivineMercyOffering),
                DecadeIndex: d, ImageOverrideKey: ImageKey));

            for (var h = 1; h <= 10; h++)
            {
                steps.Add(new RosaryStep(
                    $"For the Sake of His Sorrowful Passion ({h} of 10)", decadeSubtitle, Text(PrayerKey.DivineMercyPetition),
                    DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: ImageKey));
            }
        }

        for (var h = 1; h <= 3; h++)
        {
            steps.Add(new RosaryStep(
                $"Holy God, Holy Mighty One, Holy Immortal One ({h} of 3)", null, Text(PrayerKey.DivineMercyClosingAcclamation),
                ImageOverrideKey: ImageKey));
        }

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: ImageKey));

        return steps;
    }
}
