namespace Prosary.Models;

/// <summary>
/// The fixed, ordered list of the Seven Sorrows of Mary (the Servite Rosary/Chaplet of Our Lady of
/// Sorrows). Unlike <see cref="FranciscanCrownCatalog"/>, none of these reuse an existing Rosary
/// mystery imageKey — only the Crucifixion sorrow thematically overlaps sorrowful_05_crucifixion,
/// but is traditionally illustrated/meditated distinctly here (Mary's own vantage at the foot of
/// the Cross, not the moment of Jesus's death), so all seven get genuinely new content. A plain
/// list of imageKey strings, same reasoning as FranciscanCrownCatalog: not
/// <see cref="Mystery"/>/<see cref="MysteryGroup"/>-typed, since these aren't a Rosary "mystery
/// group" either.
/// </summary>
public static class SevenSorrowsCatalog
{
    public static readonly IReadOnlyList<string> SevenSorrows =
    [
        "seven_sorrows_01_prophecy_of_simeon",
        "seven_sorrows_02_flight_into_egypt",
        "seven_sorrows_03_loss_of_jesus_in_the_temple",
        "seven_sorrows_04_meeting_jesus_on_the_way_of_the_cross",
        "seven_sorrows_05_crucifixion",
        "seven_sorrows_06_descent_from_the_cross",
        "seven_sorrows_07_burial_of_jesus",
    ];

    /// <summary>
    /// The one sorrow with no direct Gospel citation (the meeting on the road to Calvary isn't
    /// narrated in any Gospel — it's a traditional devotional scene, the same status as the
    /// Stations of the Cross's 4th station). Its MysteryText.Description is a meditation, not a
    /// quoted verse, so the engine marks that step IsScripture = false unlike the other six.
    /// </summary>
    public const int MeetingOnTheWayIndex = 3;
}
