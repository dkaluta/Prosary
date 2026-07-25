using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the standard three-versicle Angelus, or the Easter-season Regina Caeli
/// substitute — ported from iOS's <c>StubAngelusEngine.swift</c> (no irosary precedent existed,
/// since irosary predates the Angelus entirely).</summary>
public sealed class AngelusEngine
{
    private readonly LiturgicalCalendarService _calendar;

    public AngelusEngine(LiturgicalCalendarService calendar)
    {
        _calendar = calendar;
    }

    public IReadOnlyList<RosaryStep> BuildSteps(string? languageCode)
        => BuildSteps(languageCode, _calendar.IsEasterSeasonForToday());

    /// <summary>Takes the Easter-season flag explicitly rather than always resolving it from
    /// <see cref="LiturgicalCalendarService.IsEasterSeasonForToday"/>, so tests can exercise both
    /// branches deterministically without depending on the real system date.</summary>
    internal IReadOnlyList<RosaryStep> BuildSteps(string? languageCode, bool isEasterSeason)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        if (isEasterSeason)
        {
            // During Eastertide the Angelus is traditionally replaced entirely by the Regina Caeli.
            var body = $"{Text(PrayerKey.ReginaCaeli)}\n\nV. {Text(PrayerKey.VersiculumPaschale)}" +
                       $"\nR. {Text(PrayerKey.ResponsiumPaschale)}\n\n{Text(PrayerKey.CollectaPaschale)}";
            return [new RosaryStep("Regina Caeli", null, body, ImageOverrideKey: "madonna_and_child")];
        }

        return
        [
            new RosaryStep(
                "The Annunciation", null,
                $"V. {Text(PrayerKey.VersiculumAngelusPrimus)}\nR. {Text(PrayerKey.ResponsiumAngelusPrimus)}",
                ImageOverrideKey: "joyful_01_annunciation"),
            new RosaryStep("Hail Mary", null, Text(PrayerKey.AveMaria), ImageOverrideKey: "joyful_01_annunciation"),

            new RosaryStep(
                "The Fiat", null,
                $"V. {Text(PrayerKey.VersiculumAngelusSecundus)}\nR. {Text(PrayerKey.ResponsiumAngelusSecundus)}",
                ImageOverrideKey: "joyful_01_annunciation"),
            new RosaryStep("Hail Mary", null, Text(PrayerKey.AveMaria), ImageOverrideKey: "joyful_01_annunciation"),

            new RosaryStep(
                "The Incarnation", null,
                $"V. {Text(PrayerKey.VersiculumAngelusTertius)}\nR. {Text(PrayerKey.ResponsiumAngelusTertius)}",
                ImageOverrideKey: "joyful_01_annunciation"),
            new RosaryStep("Hail Mary", null, Text(PrayerKey.AveMaria), ImageOverrideKey: "joyful_01_annunciation"),

            new RosaryStep(
                "Let Us Pray", null,
                $"V. {Text(PrayerKey.VersiculumStandard)}\nR. {Text(PrayerKey.ResponsiumStandard)}\n\n{Text(PrayerKey.CollectaAngelus)}",
                ImageOverrideKey: "joyful_01_annunciation"),
        ];
    }
}
