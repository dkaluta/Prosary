using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the ordered sequence of prayer steps for a Rosary session from a <see cref="Prayer"/>.</summary>
public sealed class RosaryEngine
{
    private static readonly string[] Ordinals = ["1st", "2nd", "3rd", "4th", "5th"];

    private static readonly (string PrayerKey, string ImageKey)[] Virtues =
    [
        (PrayerKey.AveMariaProFide, "virtue_faith"),
        (PrayerKey.AveMariaProSpe, "virtue_hope"),
        (PrayerKey.AveMariaProCaritate, "virtue_charity"),
    ];

    private readonly LiturgicalCalendarService _calendar;

    public RosaryEngine(LiturgicalCalendarService calendar)
    {
        _calendar = calendar;
    }

    /// <summary>Resolves which mystery group(s) a prayer points to, in the order they should be prayed.</summary>
    public IReadOnlyList<MysteryGroup> ResolveMysteryGroups(Prayer prayer) => prayer.Rosary.MysterySelectionMode switch
    {
        MysterySelectionMode.Specific => [prayer.Rosary.SpecificMysteryGroup],
        MysterySelectionMode.FifteenMystery => [MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
        // Chronological order of Christ's life: infancy/hidden life, public ministry, passion, glory.
        MysterySelectionMode.TwentyMystery =>
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
        _ => [_calendar.GetMysteryGroupForToday()]
    };

    public IReadOnlyList<RosaryStep> BuildSteps(Prayer prayer)
    {
        var lang = prayer.ResolvedLanguageCode;
        var options = prayer.Rosary;
        var groups = ResolveMysteryGroups(prayer);
        var steps = new List<RosaryStep>();

        string Text(string key) => PrayerTranslations.Get(lang, key);

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"));

        if (options.IncludeApostlesCreed)
        {
            steps.Add(new RosaryStep("Apostles' Creed", null, Text(PrayerKey.SymbolumApostolorum), ImageOverrideKey: "crucifix"));
        }

        if (options.IncludeOpeningPrayers)
        {
            steps.Add(new RosaryStep("Our Father", null, Text(PrayerKey.PaterNoster), ImageOverrideKey: "our_father"));
            foreach (var (virtueKey, imageKey) in Virtues)
            {
                steps.Add(new RosaryStep("Hail Mary", Text(virtueKey), Text(PrayerKey.AveMaria), ImageOverrideKey: imageKey));
            }

            steps.Add(new RosaryStep("Glory Be", null, Text(PrayerKey.GloriaPatri), ImageOverrideKey: "glory_be"));
        }

        var fruitLabel = Text(PrayerKey.FructusMysteriiLabel);

        // A session spanning more than one group (15/20-mystery) needs the group name in each
        // decade's label so it's clear which set you're in as you move from one to the next.
        var showGroupName = groups.Count > 1;

        // Global decade counter (0-based), continuing across group boundaries in a 15/20-mystery
        // session — this is what the bead progress indicator uses to tell decades apart, so it
        // must NOT reset per group.
        var decadeIndex = 0;

        foreach (var group in groups)
        {
            var mysteries = MysteryCatalog.ForGroup(group);

            for (var d = 0; d < mysteries.Count; d++)
            {
                var mystery = mysteries[d];
                var mysteryText = MysteryTranslations.Get(lang, mystery.ImageKey);
                var ordinalLabel = showGroupName ? $"{group} — {Ordinals[d]} Mystery" : $"{Ordinals[d]} Mystery";
                var decadeSubtitle = $"{ordinalLabel} — {mysteryText.Title}";
                var thisDecade = decadeIndex;

                steps.Add(new RosaryStep(mysteryText.Title, ordinalLabel,
                    $"{mysteryText.Description}\n\n{fruitLabel}: {mysteryText.Fruit}", mystery,
                    IsScripture: true, DecadeIndex: thisDecade));
                // "Our Father" gets its own dedicated image (Dürer's Praying Hands) rather than
                // staying anchored to the current decade's mystery image, same reasoning as the
                // Fatima Prayer step below.
                steps.Add(new RosaryStep("Our Father", decadeSubtitle, Text(PrayerKey.PaterNoster),
                    DecadeIndex: thisDecade, ImageOverrideKey: "our_father"));

                for (var h = 1; h <= 10; h++)
                {
                    steps.Add(new RosaryStep($"Hail Mary ({h} of 10)", decadeSubtitle, Text(PrayerKey.AveMaria), mystery,
                        DecadeIndex: thisDecade, HailMaryIndexInDecade: h));
                }

                // Same reasoning as Our Father/Fatima Prayer above: a dedicated Trinity image
                // ("Glory be to the Father, and to the Son, and to the Holy Spirit...") rather
                // than the current decade's mystery image.
                steps.Add(new RosaryStep("Glory Be", decadeSubtitle, Text(PrayerKey.GloriaPatri),
                    DecadeIndex: thisDecade, ImageOverrideKey: "glory_be"));

                if (options.IncludeFatimaPrayer)
                {
                    // "O my Jesus..." — a portrait of Christ fits better than staying anchored to
                    // the current decade's mystery image, hence no `mystery` argument here.
                    steps.Add(new RosaryStep("Fatima Prayer", decadeSubtitle, Text(PrayerKey.OratioFatimae),
                        DecadeIndex: thisDecade, ImageOverrideKey: "jesus_portrait"));
                }

                if (options.EternalRestForDeceased == EternalRestPlacement.AfterEachDecade)
                {
                    steps.Add(new RosaryStep("For the Faithful Departed", decadeSubtitle, Text(PrayerKey.RequiemAeternam),
                        DecadeIndex: thisDecade, ImageOverrideKey: "eternal_rest"));
                }

                decadeIndex++;
            }
        }

        var antiphon = ResolveMarianAntiphon(options);
        if (antiphon is { } chosen)
        {
            steps.Add(BuildAntiphonStep(chosen, Text) with { IsAntiphon = true, ImageOverrideKey = "madonna_and_child" });
        }

        if (options.IncludeStMichaelPrayer)
        {
            steps.Add(new RosaryStep("St. Michael the Archangel", null, Text(PrayerKey.SanctusMichael), ImageOverrideKey: "st_michael"));
        }

        // Prayed last, immediately before the closing Sign of the Cross — after the antiphon
        // (and St. Michael prayer, if included), matching common communal-recitation practice.
        if (options.EternalRestForDeceased == EternalRestPlacement.AtEndOnly)
        {
            steps.Add(new RosaryStep("For the Faithful Departed", null, Text(PrayerKey.RequiemAeternam), ImageOverrideKey: "eternal_rest"));
        }

        if (options.IncludeFinalSignOfCross)
        {
            steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"));
        }

        return steps;
    }

    private MarianAntiphonOption? ResolveMarianAntiphon(RosaryOptions options) => options.MarianAntiphon switch
    {
        MarianAntiphonOption.None => null,
        MarianAntiphonOption.Seasonal => _calendar.GetSeasonalMarianAntiphonForToday(),
        var chosen => chosen
    };

    private enum AntiphonStyle { Standard, Paschal, Standalone }

    private static RosaryStep BuildAntiphonStep(MarianAntiphonOption antiphon, Func<string, string> text)
    {
        var (titleKey, style) = antiphon switch
        {
            MarianAntiphonOption.SalveRegina => (PrayerKey.SalveRegina, AntiphonStyle.Standard),
            MarianAntiphonOption.AlmaRedemptorisMater => (PrayerKey.AlmaRedemptorisMater, AntiphonStyle.Standard),
            MarianAntiphonOption.AveReginaCaelorum => (PrayerKey.AveReginaCaelorum, AntiphonStyle.Standard),
            MarianAntiphonOption.ReginaCaeli => (PrayerKey.ReginaCaeli, AntiphonStyle.Paschal),
            MarianAntiphonOption.SubTuumPraesidium => (PrayerKey.SubTuumPraesidium, AntiphonStyle.Standalone),
            _ => (PrayerKey.SalveRegina, AntiphonStyle.Standard)
        };

        // Sub Tuum Praesidium is the Church's oldest known Marian prayer and is traditionally
        // prayed on its own, without the versicle/response/collect used after the four Office antiphons.
        var body = style == AntiphonStyle.Standalone
            ? text(titleKey)
            : $"{text(titleKey)}\n\nV. {text(style == AntiphonStyle.Paschal ? PrayerKey.VersiculumPaschale : PrayerKey.VersiculumStandard)}" +
              $"\nR. {text(style == AntiphonStyle.Paschal ? PrayerKey.ResponsiumPaschale : PrayerKey.ResponsiumStandard)}" +
              $"\n\n{text(style == AntiphonStyle.Paschal ? PrayerKey.CollectaPaschale : PrayerKey.CollectaStandard)}";

        return new RosaryStep(GetAntiphonHeader(antiphon), null, body);
    }

    private static string GetAntiphonHeader(MarianAntiphonOption antiphon) => antiphon switch
    {
        MarianAntiphonOption.SalveRegina => "Hail, Holy Queen (Salve Regina)",
        MarianAntiphonOption.AlmaRedemptorisMater => "Alma Redemptoris Mater",
        MarianAntiphonOption.AveReginaCaelorum => "Ave Regina Caelorum",
        MarianAntiphonOption.ReginaCaeli => "Regina Caeli",
        MarianAntiphonOption.SubTuumPraesidium => "Sub Tuum Praesidium",
        _ => "Marian Antiphon"
    };
}
