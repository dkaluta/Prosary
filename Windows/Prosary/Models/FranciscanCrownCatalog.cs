namespace Prosary.Models;

/// <summary>
/// The fixed, ordered list of the Seven Joys of Mary prayed in the Franciscan Crown. Deliberately
/// a plain list of imageKey strings rather than <see cref="Mystery"/>/<see cref="MysteryGroup"/>-typed
/// data (unlike <see cref="MysteryCatalog"/>) — the Seven Joys aren't a Rosary "mystery group" and
/// adding one as a case on MysteryGroup would pollute a type that's otherwise exclusively about
/// the 4 traditional Rosary sets. Six of the seven reuse existing Rosary mystery imageKeys/content
/// outright (Annunciation, Visitation, Nativity, Finding in the Temple, Resurrection, Coronation);
/// only the Adoration of the Magi is genuinely new content — see
/// MysteryTranslations.English.cs/MysteryTranslations.Latin.cs.
/// </summary>
public static class FranciscanCrownCatalog
{
    public static readonly IReadOnlyList<string> SevenJoys =
    [
        "joyful_01_annunciation",
        "joyful_02_visitation",
        "joyful_03_nativity",
        "franciscan_04_adoration_of_the_magi",
        "joyful_05_finding_in_the_temple",
        "glorious_01_resurrection",
        "glorious_05_coronation",
    ];
}
