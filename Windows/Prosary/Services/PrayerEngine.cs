using System.Linq;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>The single production step-builder for every devotion. <see cref="BuildSteps"/>
/// dispatches on <see cref="Prayer.Kind"/>: the Rosary keeps its own hardcoded,
/// options/calendar-driven builder (it is the one deeply configurable devotion); the Jesus Prayer
/// has no steps at all (a repetition counter — see JesusPrayerViewModel); and every other
/// devotion is Custom — fully data-driven from its .prosaryprayer bundle's devotion.json via
/// <see cref="BuildCustomDevotionSteps(string, string?, bool, MarianAntiphonOption)"/>.
/// <see cref="BuildDecadeSteps"/> and <see cref="BuildMarianAntiphonStep"/> remain as the
/// Rosary's own helpers; the generic rosary-type builder mirrors their emission so bead tracks
/// behave identically everywhere. Mirrors iOS's PrayerEngine.swift/Android's PrayerEngine.kt.</summary>
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
        // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
        // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
        // JesusPrayerViewModel, which never calls this engine at all.
        PrayerKind.JesusPrayer => [],
        PrayerKind.Custom => prayer.CustomDevotionId is { } bundleId
            ? BuildCustomDevotionSteps(bundleId, prayer.LanguageCode, prayer.VariantId)
            : [],
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

    // Marian antiphon (shared by the Rosary and generic rosary-type devotions)

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
            : $"{Text(titleKey)}\n\n{Text(style == AntiphonStyle.Paschal ? PrayerKey.VersiculumPaschale : PrayerKey.VersiculumStandard)}" +
              $"\n**{Text(style == AntiphonStyle.Paschal ? PrayerKey.ResponsiumPaschale : PrayerKey.ResponsiumStandard)}**" +
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

    // Custom (bundle-driven) devotions

    private IReadOnlyList<RosaryStep> BuildCustomDevotionSteps(string bundleId, string? languageCode, string? variantId = null) =>
        BuildCustomDevotionSteps(
            bundleId, languageCode,
            _calendar.IsEasterSeasonForToday(), _calendar.GetSeasonalMarianAntiphonForToday(), variantId);

    /// <summary>The only builder for every <see cref="PrayerKind.Custom"/> devotion — reads
    /// <paramref name="bundleId"/>'s parsed <c>devotion.json</c> and produces the full step
    /// sequence with no devotion-specific code. The flat "steps" type covers
    /// Angelus/Stations/Trisagion-shaped devotions (including the Angelus's Eastertide
    /// whole-sequence swap); the decade/bead-structured "rosary" type covers Franciscan
    /// Crown/Seven Sorrows/Divine Mercy-shaped ones. Takes the calendar-derived values
    /// explicitly so tests can
    /// exercise both Eastertide branches and any season's antiphon deterministically.</summary>
    internal static IReadOnlyList<RosaryStep> BuildCustomDevotionSteps(
        string bundleId, string? languageCode, bool isEasterSeason, MarianAntiphonOption seasonalAntiphon,
        string? variantId = null)
    {
        var definition = PrayerPackStore.Definition(bundleId);
        if (definition is null) return [];

        switch (definition.Type)
        {
            case CustomDevotionDefinition.DevotionType.Steps:
                var (baseSteps, eastertideSteps) = definition.ResolvedSteps(variantId);
                var entries = (isEasterSeason ? eastertideSteps : null) ?? baseSteps;
                return entries.SelectMany(e => Expand(e, bundleId, languageCode, seasonalAntiphon)).ToList();
            case CustomDevotionDefinition.DevotionType.Rosary:
                return BuildCustomRosarySteps(definition, bundleId, languageCode, seasonalAntiphon);
            default:
                return [];
        }
    }

    /// <summary>Expands one <c>devotion.json</c> entry into its step(s): resolves the title
    /// (literal or translated <c>titleKey</c>) and body, and unrolls <c>repeat</c> into
    /// "(h of n)"-suffixed copies — deliberately without bead fields, matching the hardcoded
    /// devotions' closing Hail Marys.</summary>
    private static IReadOnlyList<RosaryStep> Expand(
        CustomDevotionStep entry, string bundleId, string? languageCode, MarianAntiphonOption seasonalAntiphon)
    {
        if (entry.Kind == CustomDevotionStep.SpecialKind.SeasonalMarianAntiphon)
        {
            return [BuildMarianAntiphonStep(seasonalAntiphon, languageCode)];
        }

        var title = entry.TitleKey is { } titleKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, titleKey)
            : entry.Title ?? string.Empty;
        var body = entry.BodyKey is { } bodyKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, bodyKey)
            : string.Empty;

        if (entry.Repeat is not { } count || count <= 1)
        {
            return [new RosaryStep(title, entry.Subtitle, body, ImageOverrideKey: entry.ImageKey)];
        }

        return Enumerable.Range(1, count)
            .Select(h => new RosaryStep($"{title} ({h} of {count})", entry.Subtitle, body, ImageOverrideKey: entry.ImageKey))
            .ToList();
    }

    /// <summary>The decade/bead-structured generic builder ("rosary" type) — mirrors
    /// <see cref="BuildDecadeSteps"/>'s emission exactly (announcement → major → N minors, dense
    /// global DecadeIndex, HailMaryIndexInDecade on minors only, "ordinal — title" subtitles) so
    /// the bead track and step chrome behave identically to the previously hardcoded decade
    /// devotions.</summary>
    private static IReadOnlyList<RosaryStep> BuildCustomRosarySteps(
        CustomDevotionDefinition definition, string bundleId, string? languageCode, MarianAntiphonOption seasonalAntiphon)
    {
        if (definition.Decades is not { } decades) return [];

        string Resolve(string key) => PrayerPackStore.ResolveBodyText(bundleId, languageCode, key);

        var steps = new List<RosaryStep>();
        foreach (var entry in definition.Opening ?? [])
        {
            steps.AddRange(Expand(entry, bundleId, languageCode, seasonalAntiphon));
        }

        var fruitLabel = PrayerTranslations.Get(languageCode, PrayerKey.FructusMysteriiLabel);
        var majorBody = Resolve(decades.MajorStep.BodyKey);
        var minorBody = Resolve(decades.MinorStep.BodyKey);
        var decadeCount = decades.Entries?.Count ?? decades.Count ?? 0;

        for (var d = 0; d < decadeCount; d++)
        {
            var entry = decades.Entries?[d];
            var imageKey = entry?.ImageKey ?? decades.FixedImageKey;
            var ordinalLabel = $"{Ordinals[d]} {decades.OrdinalNoun}";
            var decadeSubtitle = ordinalLabel;

            if (decades.AnnounceMystery && entry is not null)
            {
                var mysteryText = MysteryTranslations.Get(languageCode, entry.ImageKey);
                var body = mysteryText.Description;
                if (!string.IsNullOrEmpty(mysteryText.Fruit))
                {
                    body += $"\n\n{fruitLabel}: {mysteryText.Fruit}";
                }

                steps.Add(new RosaryStep(mysteryText.Title, ordinalLabel, body,
                    IsScripture: entry.IsScripture ?? true, DecadeIndex: d, ImageOverrideKey: entry.ImageKey));
                decadeSubtitle = $"{ordinalLabel} — {mysteryText.Title}";
            }

            steps.Add(new RosaryStep(decades.MajorStep.Title, decadeSubtitle, majorBody,
                DecadeIndex: d, ImageOverrideKey: imageKey));

            for (var h = 1; h <= decades.MinorCount; h++)
            {
                steps.Add(new RosaryStep(
                    $"{decades.MinorStep.Title} ({h} of {decades.MinorCount})", decadeSubtitle, minorBody,
                    DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: imageKey));
            }
        }

        foreach (var entry in definition.Closing ?? [])
        {
            steps.AddRange(Expand(entry, bundleId, languageCode, seasonalAntiphon));
        }

        return steps;
    }
}
