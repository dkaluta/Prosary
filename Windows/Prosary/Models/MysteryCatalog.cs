namespace Prosary.Models;

/// <summary>The fixed catalog of all twenty mysteries, grouped and ordered. Display text lives in
/// <see cref="Prosary.Localization.MysteryTranslations"/>, keyed by each mystery's <see cref="Mystery.ImageKey"/>.</summary>
public static class MysteryCatalog
{
    public static readonly IReadOnlyList<Mystery> Joyful =
    [
        new(MysteryGroup.Joyful, 1, "joyful_01_annunciation"),
        new(MysteryGroup.Joyful, 2, "joyful_02_visitation"),
        new(MysteryGroup.Joyful, 3, "joyful_03_nativity"),
        new(MysteryGroup.Joyful, 4, "joyful_04_presentation"),
        new(MysteryGroup.Joyful, 5, "joyful_05_finding_in_the_temple"),
    ];

    public static readonly IReadOnlyList<Mystery> Sorrowful =
    [
        new(MysteryGroup.Sorrowful, 1, "sorrowful_01_agony_in_the_garden"),
        new(MysteryGroup.Sorrowful, 2, "sorrowful_02_scourging_at_the_pillar"),
        new(MysteryGroup.Sorrowful, 3, "sorrowful_03_crowning_with_thorns"),
        new(MysteryGroup.Sorrowful, 4, "sorrowful_04_carrying_of_the_cross"),
        new(MysteryGroup.Sorrowful, 5, "sorrowful_05_crucifixion"),
    ];

    public static readonly IReadOnlyList<Mystery> Glorious =
    [
        new(MysteryGroup.Glorious, 1, "glorious_01_resurrection"),
        new(MysteryGroup.Glorious, 2, "glorious_02_ascension"),
        new(MysteryGroup.Glorious, 3, "glorious_03_descent_of_the_holy_spirit"),
        new(MysteryGroup.Glorious, 4, "glorious_04_assumption"),
        new(MysteryGroup.Glorious, 5, "glorious_05_coronation"),
    ];

    public static readonly IReadOnlyList<Mystery> Luminous =
    [
        new(MysteryGroup.Luminous, 1, "luminous_01_baptism"),
        new(MysteryGroup.Luminous, 2, "luminous_02_wedding_at_cana"),
        new(MysteryGroup.Luminous, 3, "luminous_03_proclamation_of_the_kingdom"),
        new(MysteryGroup.Luminous, 4, "luminous_04_transfiguration"),
        new(MysteryGroup.Luminous, 5, "luminous_05_institution_of_the_eucharist"),
    ];

    public static IReadOnlyList<Mystery> ForGroup(MysteryGroup group) => group switch
    {
        MysteryGroup.Joyful => Joyful,
        MysteryGroup.Sorrowful => Sorrowful,
        MysteryGroup.Glorious => Glorious,
        MysteryGroup.Luminous => Luminous,
        _ => throw new ArgumentOutOfRangeException(nameof(group))
    };

    public static IEnumerable<Mystery> All => Joyful.Concat(Sorrowful).Concat(Glorious).Concat(Luminous);
}
