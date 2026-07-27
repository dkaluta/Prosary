using System.Linq;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>The single production step-builder for every devotion. <see cref="BuildSteps"/>
/// dispatches on <see cref="Prayer.Kind"/> to one of 6 private builders. Angelus/Stations have no
/// decades and a different per-item template each, so they keep their own builders rather than
/// being forced through the decade-shaped helper below; Divine Mercy Chaplet has no catalog (it
/// repeats the same 2 lines every decade, not per-decade content), so it doesn't fit the
/// catalog-driven shape either. The Rosary's per-group decade loop and Franciscan Crown/Seven
/// Sorrows' single decade loop DO share the same underlying shape (announce → Our Father → N Hail
/// Marys) — that shared shape is <see cref="BuildDecadeSteps"/>, the one genuine algorithmic
/// unification here, not just a class merge.
///
/// Replaces 6 classes (RosaryEngine/AngelusEngine/StationsEngine/FranciscanCrownEngine/
/// SevenSorrowsEngine/DivineMercyEngine) and their separate DI registrations. Mirrors iOS's
/// PrayerEngine.swift/Android's PrayerEngine.kt.</summary>
public sealed class PrayerEngine
{
    private static readonly string[] Ordinals =
    [
        "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
        "8th", "9th", "10th", "11th", "12th", "13th", "14th",
    ];

    private static readonly (string Key, string ImageKey)[] Virtues =
    [
        (PrayerKey.AveMariaProFide, "virtue_faith"),
        (PrayerKey.AveMariaProSpe, "virtue_hope"),
        (PrayerKey.AveMariaProCaritate, "virtue_charity"),
    ];

    private readonly LiturgicalCalendarService _calendar;

    public PrayerEngine(LiturgicalCalendarService calendar)
    {
        _calendar = calendar;
    }

    public IReadOnlyList<RosaryStep> BuildSteps(Prayer prayer) => prayer.Kind switch
    {
        PrayerKind.Rosary => BuildRosarySteps(prayer),
        PrayerKind.Angelus => BuildAngelusSteps(prayer.LanguageCode),
        // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
        // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
        // JesusPrayerViewModel, which never calls this engine at all.
        PrayerKind.JesusPrayer => [],
        PrayerKind.StationsOfTheCross => BuildStationsSteps(prayer.LanguageCode),
        PrayerKind.FranciscanCrown => BuildFranciscanCrownSteps(prayer.LanguageCode),
        PrayerKind.SevenSorrows => BuildSevenSorrowsSteps(prayer.LanguageCode),
        PrayerKind.DivineMercyChaplet => BuildDivineMercySteps(prayer.LanguageCode),
        _ => throw new ArgumentOutOfRangeException(nameof(prayer), prayer.Kind, "Unhandled PrayerKind in PrayerEngine.BuildSteps")
    };

    // Rosary

    /// <summary>Resolves which mystery group(s) a prayer points to, in the order they should be prayed.</summary>
    public IReadOnlyList<MysteryGroup> ResolveMysteryGroups(Prayer prayer) => prayer.Rosary.MysterySelectionMode switch
    {
        MysterySelectionMode.Specific or MysterySelectionMode.SingleMystery => [prayer.Rosary.SpecificMysteryGroup],
        MysterySelectionMode.FifteenMystery => [MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
        MysterySelectionMode.TwentyMystery =>
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
        _ => [_calendar.GetMysteryGroupForToday()]
    };

    private IReadOnlyList<RosaryStep> BuildRosarySteps(Prayer prayer)
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
        var showGroupName = groups.Count > 1;
        var decadeIndex = 0;

        foreach (var group in groups)
        {
            var mysteries = MysteryCatalog.ForGroup(group);
            IEnumerable<int> indices = options.MysterySelectionMode == MysterySelectionMode.SingleMystery
                ? [options.SpecificMysteryOrder - 1]
                : Enumerable.Range(0, mysteries.Count);

            foreach (var d in indices)
            {
                var mystery = mysteries[d];
                var mysteryText = MysteryTranslations.Get(lang, mystery.ImageKey);
                var ordinalLabel = showGroupName ? $"{group} — {Ordinals[d]} Mystery" : $"{Ordinals[d]} Mystery";
                var thisDecade = decadeIndex;
                var decadeSubtitle = $"{ordinalLabel} — {mysteryText.Title}";

                if (options.PresenterMode)
                {
                    steps.Add(new RosaryStep(mysteryText.Title, ordinalLabel,
                        $"{mysteryText.Description}\n\n{fruitLabel}: {mysteryText.Fruit}",
                        mystery, IsScripture: true, DecadeIndex: thisDecade));
                    steps.Add(new RosaryStep("Our Father", decadeSubtitle, Text(PrayerKey.PaterNoster),
                        DecadeIndex: thisDecade, ImageOverrideKey: "our_father"));
                    steps.Add(new RosaryStep("Hail Mary & Glory Be", decadeSubtitle,
                        $"{Text(PrayerKey.AveMaria)}\n\n{Text(PrayerKey.GloriaPatri)}",
                        mystery, DecadeIndex: thisDecade, HailMaryIndexInDecade: 10));
                }
                else
                {
                    steps.AddRange(BuildDecadeSteps(
                        decadeIndex: thisDecade, announcementTitle: mysteryText.Title, ordinalLabel: ordinalLabel,
                        announcementBody: $"{mysteryText.Description}\n\n{fruitLabel}: {mysteryText.Fruit}",
                        mystery: mystery, decadeImageKey: null, isScripture: true,
                        ourFatherImageKey: "our_father", hailMarysPerDecade: 10, languageCode: lang));

                    steps.Add(new RosaryStep("Glory Be", decadeSubtitle, Text(PrayerKey.GloriaPatri),
                        DecadeIndex: thisDecade, ImageOverrideKey: "glory_be"));
                }

                if (options.IncludeFatimaPrayer)
                {
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
            steps.Add(BuildMarianAntiphonStep(chosen, lang));
        }

        if (options.IncludeStMichaelPrayer)
        {
            steps.Add(new RosaryStep("St. Michael the Archangel", null, Text(PrayerKey.SanctusMichael), ImageOverrideKey: "st_michael"));
        }

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

    // Shared decade-building helper (Rosary's inner loop, Franciscan Crown, Seven Sorrows)

    /// <summary>Builds one decade: an announcement step, an Our Father step, and
    /// <paramref name="hailMarysPerDecade"/> Hail Mary steps. <paramref name="mystery"/>/
    /// <paramref name="decadeImageKey"/> together control each step's illustration — pass a real
    /// <see cref="Mystery"/> (Rosary) to let steps fall through to its own ImageKey, or a null
    /// mystery plus an explicit <paramref name="decadeImageKey"/> (Franciscan Crown/Seven
    /// Sorrows, whose catalogs are plain imageKey strings, not Mystery-typed).
    /// <paramref name="ourFatherImageKey"/> is separate from <paramref name="decadeImageKey"/>
    /// because the Rosary's Our Father step always shows a fixed generic icon ("our_father")
    /// between mystery-specific images, while Franciscan Crown/Seven Sorrows keep showing that
    /// decade's own illustration straight through — a real, deliberate difference between how
    /// these devotions render, not an inconsistency to paper over.</summary>
    private static IReadOnlyList<RosaryStep> BuildDecadeSteps(
        int decadeIndex, string announcementTitle, string ordinalLabel, string announcementBody,
        Mystery? mystery, string? decadeImageKey, bool isScripture,
        string? ourFatherImageKey, int hailMarysPerDecade, string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var decadeSubtitle = $"{ordinalLabel} — {announcementTitle}";

        var steps = new List<RosaryStep>
        {
            new(announcementTitle, ordinalLabel, announcementBody, mystery,
                IsScripture: isScripture, DecadeIndex: decadeIndex, ImageOverrideKey: decadeImageKey),
            new("Our Father", decadeSubtitle, Text(PrayerKey.PaterNoster),
                DecadeIndex: decadeIndex, ImageOverrideKey: ourFatherImageKey),
        };

        for (var h = 1; h <= hailMarysPerDecade; h++)
        {
            steps.Add(new RosaryStep($"Hail Mary ({h} of {hailMarysPerDecade})", decadeSubtitle, Text(PrayerKey.AveMaria), mystery,
                DecadeIndex: decadeIndex, HailMaryIndexInDecade: h, ImageOverrideKey: decadeImageKey));
        }

        return steps;
    }

    // Franciscan Crown

    private IReadOnlyList<RosaryStep> BuildFranciscanCrownSteps(string? languageCode)
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

            steps.AddRange(BuildDecadeSteps(
                decadeIndex: d, announcementTitle: joyText.Title, ordinalLabel: ordinalLabel,
                announcementBody: $"{joyText.Description}\n\n{fruitLabel}: {joyText.Fruit}",
                mystery: null, decadeImageKey: imageKey, isScripture: true,
                ourFatherImageKey: imageKey, hailMarysPerDecade: 10, languageCode: languageCode));
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

        steps.Add(BuildMarianAntiphonStep(_calendar.GetSeasonalMarianAntiphonForToday(), languageCode));

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: "crucifix"));

        return steps;
    }

    // Seven Sorrows

    private static IReadOnlyList<RosaryStep> BuildSevenSorrowsSteps(string? languageCode)
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

            steps.AddRange(BuildDecadeSteps(
                decadeIndex: d, announcementTitle: sorrowText.Title, ordinalLabel: ordinalLabel,
                announcementBody: $"{sorrowText.Description}\n\n{fruitLabel}: {sorrowText.Fruit}",
                mystery: null, decadeImageKey: imageKey, isScripture: d != SevenSorrowsCatalog.MeetingOnTheWayIndex,
                ourFatherImageKey: imageKey, hailMarysPerDecade: 7, languageCode: languageCode));
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

    // Divine Mercy Chaplet

    private static IReadOnlyList<RosaryStep> BuildDivineMercySteps(string? languageCode)
    {
        const string imageKey = "divine_mercy_image";

        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var steps = new List<RosaryStep>
        {
            new("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: imageKey),
            new("Our Father", null, Text(PrayerKey.PaterNoster), ImageOverrideKey: imageKey),
            new("Hail Mary", null, Text(PrayerKey.AveMaria), ImageOverrideKey: imageKey),
            new("The Apostles' Creed", null, Text(PrayerKey.SymbolumApostolorum), ImageOverrideKey: imageKey),
        };

        for (var d = 0; d < 5; d++)
        {
            var decadeSubtitle = $"{Ordinals[d]} Decade";

            steps.Add(new RosaryStep(
                "Eternal Father, I Offer You...", decadeSubtitle, Text(PrayerKey.DivineMercyOffering),
                DecadeIndex: d, ImageOverrideKey: imageKey));

            for (var h = 1; h <= 10; h++)
            {
                steps.Add(new RosaryStep(
                    $"For the Sake of His Sorrowful Passion ({h} of 10)", decadeSubtitle, Text(PrayerKey.DivineMercyPetition),
                    DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: imageKey));
            }
        }

        for (var h = 1; h <= 3; h++)
        {
            steps.Add(new RosaryStep(
                $"Holy God, Holy Mighty One, Holy Immortal One ({h} of 3)", null, Text(PrayerKey.DivineMercyClosingAcclamation),
                ImageOverrideKey: imageKey));
        }

        steps.Add(new RosaryStep("Sign of the Cross", null, Text(PrayerKey.SignumCrucis), ImageOverrideKey: imageKey));

        return steps;
    }

    // Angelus

    private IReadOnlyList<RosaryStep> BuildAngelusSteps(string? languageCode)
        => BuildAngelusSteps(languageCode, _calendar.IsEasterSeasonForToday());

    /// <summary>Takes the Easter-season flag explicitly rather than always resolving it from
    /// <see cref="LiturgicalCalendarService.IsEasterSeasonForToday"/>, so tests can exercise both
    /// branches deterministically without depending on the real system date.</summary>
    internal static IReadOnlyList<RosaryStep> BuildAngelusSteps(string? languageCode, bool isEasterSeason)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        if (isEasterSeason)
        {
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

    // Stations of the Cross

    private static IReadOnlyList<RosaryStep> BuildStationsSteps(string? languageCode)
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

    // Marian antiphon (shared by Rosary and Franciscan Crown)

    private enum AntiphonStyle { Standard, Paschal, Standalone }

    private static RosaryStep BuildMarianAntiphonStep(MarianAntiphonOption antiphon, string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

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
            ? Text(titleKey)
            : $"{Text(titleKey)}\n\nV. {Text(style == AntiphonStyle.Paschal ? PrayerKey.VersiculumPaschale : PrayerKey.VersiculumStandard)}" +
              $"\nR. {Text(style == AntiphonStyle.Paschal ? PrayerKey.ResponsiumPaschale : PrayerKey.ResponsiumStandard)}" +
              $"\n\n{Text(style == AntiphonStyle.Paschal ? PrayerKey.CollectaPaschale : PrayerKey.CollectaStandard)}";

        return new RosaryStep(GetMarianAntiphonHeader(antiphon), null, body) with { IsAntiphon = true, ImageOverrideKey = "madonna_and_child" };
    }

    // Preserves a pre-existing minor divergence from iOS/Android (which just say "Salve Regina")
    // — kept as-is when this was originally extracted into MarianAntiphonBuilder, not "fixed".
    private static string GetMarianAntiphonHeader(MarianAntiphonOption antiphon) => antiphon switch
    {
        MarianAntiphonOption.SalveRegina => "Hail, Holy Queen (Salve Regina)",
        MarianAntiphonOption.AlmaRedemptorisMater => "Alma Redemptoris Mater",
        MarianAntiphonOption.AveReginaCaelorum => "Ave Regina Caelorum",
        MarianAntiphonOption.ReginaCaeli => "Regina Caeli",
        MarianAntiphonOption.SubTuumPraesidium => "Sub Tuum Praesidium",
        _ => "Marian Antiphon"
    };
}
