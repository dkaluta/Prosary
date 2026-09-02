using System.Linq;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>The single production step-builder for every devotion. <see cref="BuildSteps"/>
/// dispatches on <see cref="Prayer.Kind"/>: the Jesus Prayer has no steps at all (a repetition
/// counter — see JesusPrayerViewModel); everything else — the Rosary included — is data-driven
/// from a .prosaryprayer bundle's devotion.json via the generic builders. The Rosary's
/// option/calendar-driven pieces stay engine-side behind the bundle's
/// <c>decades.source: "mysteryGroups"</c> (see <see cref="BuildMysteryGroupDecades"/>), with
/// <see cref="RosaryOptions"/> mapped onto the bundle's options.json values by
/// <see cref="RosaryOptionValues"/> — no data migration. The retired hardcoded builder's output
/// was pinned byte-for-byte before deletion on iOS/Android (RosaryEngineTests' one-time parity
/// sweep, kept in git history). Mirrors iOS's PrayerEngine.swift/Android's PrayerEngine.kt.</summary>
public sealed class PrayerEngine
{
    private static readonly string[] Ordinals =
    [
        "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
        "8th", "9th", "10th", "11th", "12th", "13th", "14th",
    ];

    private readonly LiturgicalCalendarService _calendar;

    public PrayerEngine(LiturgicalCalendarService calendar)
    {
        _calendar = calendar;
    }

    public IReadOnlyList<RosaryStep> BuildSteps(Prayer prayer) => prayer.Kind switch
    {
        // The Rosary builds from the rosary bundle's devotion.json like every other devotion —
        // RosaryOptions stays the persisted shape (no data migration; the bespoke editor keeps
        // writing it) and is mapped onto the bundle's option values here.
        PrayerKind.Rosary => BuildCustomDevotionSteps(
            "rosary", prayer.ResolvedLanguageCode, variantId: null,
            optionOverrides: RosaryOptionValues(prayer.Rosary), rosaryOptions: prayer.Rosary),
        // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
        // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
        // JesusPrayerViewModel, which never calls this engine at all.
        PrayerKind.JesusPrayer => [],
        PrayerKind.Custom => prayer.CustomDevotionId is { } bundleId
            ? BuildCustomDevotionSteps(
                bundleId, PrayerPackStore.EffectiveLanguage(bundleId, prayer.LanguageCode),
                prayer.VariantId, prayer.CustomOptions, dayIndex: prayer.DayIndex ?? 0)
            : [],
        _ => throw new ArgumentOutOfRangeException(nameof(prayer), prayer.Kind, "Unhandled PrayerKind in PrayerEngine.BuildSteps")
    };

    // Rosary

    /// <summary>Resolves which mystery group(s) a prayer points to, in the order they should be prayed.</summary>
    public IReadOnlyList<MysteryGroup> ResolveMysteryGroups(Prayer prayer) => ResolveMysteryGroups(prayer.Rosary);

    public IReadOnlyList<MysteryGroup> ResolveMysteryGroups(RosaryOptions rosary) =>
        ResolveMysteryGroups(rosary, _calendar.GetMysteryGroupForToday());

    private static IReadOnlyList<MysteryGroup> ResolveMysteryGroups(RosaryOptions rosary, MysteryGroup todaysGroup) =>
        rosary.MysterySelectionMode switch
        {
            MysterySelectionMode.Specific or MysterySelectionMode.SingleMystery => [rosary.SpecificMysteryGroup],
            MysterySelectionMode.FifteenMystery => [MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            MysterySelectionMode.TwentyMystery =>
                [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            _ => [todaysGroup]
        };

    /// <summary>Maps the persisted <see cref="RosaryOptions"/> onto the rosary bundle's
    /// options.json values — the no-data-migration seam: favorites keep their typed columns and
    /// bespoke editor, while the engine speaks the bundle's generic option encoding.</summary>
    internal static Dictionary<string, string> RosaryOptionValues(RosaryOptions rosary)
    {
        var savedAramaicForm = rosary.AramaicSignOfCrossForm == AppSettings.AramaicSignOfCrossFormB
            ? AppSettings.AramaicSignOfCrossFormB
            : AppSettings.AramaicSignOfCrossFormA;
        var effectiveAramaicForm = AppSettings.UsesSystemWideAramaicSignOfCrossForm
            ? AppSettings.AramaicSignOfCrossForm
            : savedAramaicForm;
        return new()
        {
        ["apostlesCreed"] = rosary.IncludeApostlesCreed ? "true" : "false",
        ["aramaicSignOfCrossForm"] = effectiveAramaicForm,
        ["openingPrayers"] = rosary.IncludeOpeningPrayers ? "true" : "false",
        ["presenterMode"] = rosary.PresenterMode ? "true" : "false",
        ["fatimaPrayer"] = rosary.IncludeFatimaPrayer ? "true" : "false",
        ["eternalRest"] = CamelCase(rosary.EternalRestForDeceased.ToString()),
        ["antiphon"] = CamelCase(rosary.MarianAntiphon.ToString()),
        ["closingIntentions"] = rosary.IncludeClosingIntentions ? "true" : "false",
        ["stMichael"] = rosary.IncludeStMichaelPrayer ? "true" : "false",
        ["finalSignOfCross"] = rosary.IncludeFinalSignOfCross ? "true" : "false",
        ["imageStyle"] = CamelCase(rosary.MysteryImageStyle.ToString()),
        };
    }

    private static string CamelCase(string name) =>
        name.Length == 0 ? name : char.ToLowerInvariant(name[0]) + name[1..];

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

        return new RosaryStep(Text(GetMarianAntiphonHeaderKey(antiphon)), null, body) with { IsAntiphon = true, ImageOverrideKey = "madonna_and_child" };
    }

    // The heading names the antiphon in the language being prayed, not in Latin — the same
    // choice the step's body already makes. (This also retires a pre-existing divergence from
    // iOS/Android, which used to hardcode a different English form here.)
    private static string GetMarianAntiphonHeaderKey(MarianAntiphonOption antiphon) => antiphon switch
    {
        MarianAntiphonOption.SalveRegina => PrayerKey.SalveReginaTitle,
        MarianAntiphonOption.AlmaRedemptorisMater => PrayerKey.AlmaRedemptorisMaterTitle,
        MarianAntiphonOption.AveReginaCaelorum => PrayerKey.AveReginaCaelorumTitle,
        MarianAntiphonOption.ReginaCaeli => PrayerKey.ReginaCaeliTitle,
        MarianAntiphonOption.SubTuumPraesidium => PrayerKey.SubTuumPraesidiumTitle,
        // Unreachable: both resolve to a concrete antiphon before this is called.
        _ => PrayerKey.SalveReginaTitle
    };

    // A decade's ordinal in the language being prayed: "1st Mystery" in English, "רז 1" in
    // Hebrew. English is the only one of the six languages that inflects the number itself,
    // so it alone takes an ordinal word; the rest read the plain digit.
    private static string DecadeOrdinal(
        int index, CustomDevotionDefinition.DecadesDefinition decades, string bundleId, string? languageCode)
    {
        var noun = decades.OrdinalNounKey is { } key
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, key)
            : decades.OrdinalNoun ?? string.Empty;
        var isEnglish = languageCode is { } code && (LanguageCatalog.BaseLanguage(code) ?? code) == "en";
        var number = isEnglish && index < Ordinals.Length ? Ordinals[index] : $"{index + 1}";
        return PrayerTranslations.Get(languageCode, PrayerKey.DecadeOrdinalFormat)
            .Replace("{n}", number)
            .Replace("{noun}", noun);
    }

    // "(3 of 10)" for a repeated step, connector translated into the prayer's own language.
    private static string Counter(int index, int total, string? languageCode) =>
        $"({index} {PrayerTranslations.Get(languageCode, PrayerKey.RepetitionCounterConnector)} {total})";

    // Custom (bundle-driven) devotions

    private IReadOnlyList<RosaryStep> BuildCustomDevotionSteps(
        string bundleId, string? languageCode, string? variantId = null,
        Dictionary<string, string>? optionOverrides = null, RosaryOptions? rosaryOptions = null,
        int dayIndex = 0) =>
        BuildCustomDevotionSteps(
            bundleId, languageCode,
            _calendar.IsEasterSeasonForToday(), _calendar.GetSeasonalMarianAntiphonForToday(), variantId,
            optionOverrides, rosaryOptions, _calendar.GetMysteryGroupForToday(), dayIndex,
            _calendar.IsLentForToday());

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
        string? variantId = null, Dictionary<string, string>? optionOverrides = null,
        RosaryOptions? rosaryOptions = null, MysteryGroup todaysGroup = MysteryGroup.Joyful,
        int dayIndex = 0, bool isLent = false)
    {
        var definition = PrayerPackStore.Definition(bundleId);
        if (definition is null) return [];

        // No explicit variant on the favorite → the form the prayer language declares as its
        // own (the Mission's rite opens the Trisagion Syriac), else the first.
        variantId = definition.EffectiveVariantId(variantId, languageCode);

        // Effective option values: the bundle's declared defaults overlaid with the favorite's
        // stored choices. Overrides for keys the bundle no longer declares are ignored, so a
        // stale favorite can't gate on options that stopped existing.
        var optionValues = new Dictionary<string, string>();
        foreach (var option in PrayerPackStore.Options(bundleId))
        {
            optionValues[option.Key] = optionOverrides?.GetValueOrDefault(option.Key) ?? option.DefaultValue;
        }

        // Calendar facts an entry may gate on beside the user's own choices — the Alleluia that
        // leaves the invitatory during Lent is the first of them. Seeded after the declared
        // options and reserved by the validator, so a bundle cannot declare an option of the
        // same name and shadow the season.
        optionValues["isLent"] = isLent ? "true" : "false";
        optionValues["isEasterSeason"] = isEasterSeason ? "true" : "false";

        switch (definition.Type)
        {
            case CustomDevotionDefinition.DevotionType.Steps:
                var (baseSteps, eastertideSteps) = definition.ResolvedSteps(variantId);
                var entries = (isEasterSeason ? eastertideSteps : null) ?? baseSteps;
                return entries.SelectMany(e => Expand(e, bundleId, languageCode, seasonalAntiphon, optionValues)).ToList();
            case CustomDevotionDefinition.DevotionType.Rosary:
                return BuildCustomRosarySteps(
                    definition, bundleId, languageCode, seasonalAntiphon, optionValues, rosaryOptions,
                    todaysGroup, variantId);
            case CustomDevotionDefinition.DevotionType.Days:
                // Multi-day devotions: shared opening + the day's own steps + shared closing.
                // dayIndex is clamped, so a finished novena keeps praying its last day; the
                // per-favorite progress that will drive it is a planned follow-up (see
                // ARCHITECTURE.md) — until it lands, sessions pray day 1.
                if (definition.Days is not { Count: > 0 } days) return [];
                var day = days[Math.Clamp(dayIndex, 0, days.Count - 1)];
                return (definition.Opening ?? []).Concat(day.Steps ?? []).Concat(definition.Closing ?? [])
                    .SelectMany(e => Expand(e, bundleId, languageCode, seasonalAntiphon, optionValues))
                    .ToList();
            default:
                return [];
        }
    }

    /// <summary>Evaluates an entry's <c>"if"</c> gate against the effective option values:
    /// <c>"key"</c> — toggle on; <c>"!key"</c> — toggle off; <c>"key=caseId"</c> — choice
    /// equals. The validator guarantees every authored expression references a declared option,
    /// so a missing key (impossible for shipped bundles) simply reads as "not on".</summary>
    /// <summary>"key" — toggle on; "!key" — toggle off; "key=caseId" — choice equals; and
    /// "a &amp; b" — every term must hold, which is how a step gates on a choice *and* the
    /// season ("invitatory &amp; !isLent").</summary>
    internal static bool EvaluateCondition(string expression, IReadOnlyDictionary<string, string> values) =>
        expression.Split('&').All(term => EvaluateTerm(term.Trim(), values));

    private static bool EvaluateTerm(string term, IReadOnlyDictionary<string, string> values)
    {
        var equals = term.IndexOf('=');
        if (equals >= 0)
        {
            return values.GetValueOrDefault(term[..equals]) == term[(equals + 1)..];
        }

        if (term.StartsWith('!'))
        {
            return values.GetValueOrDefault(term[1..]) != "true";
        }

        return values.GetValueOrDefault(term) == "true";
    }

    /// <summary>Expands one <c>devotion.json</c> entry into its step(s): resolves the title
    /// (literal or translated <c>titleKey</c>) and body, and unrolls <c>repeat</c> into
    /// "(h of n)"-suffixed copies — deliberately without bead fields, matching the hardcoded
    /// devotions' closing Hail Marys.</summary>
    private static IReadOnlyList<RosaryStep> Expand(
        CustomDevotionStep entry, string bundleId, string? languageCode, MarianAntiphonOption seasonalAntiphon,
        IReadOnlyDictionary<string, string>? optionValues = null)
    {
        if (entry.If is { } condition && !EvaluateCondition(condition, optionValues ?? new Dictionary<string, string>()))
        {
            return [];
        }

        if (entry.Kind == CustomDevotionStep.SpecialKind.SeasonalMarianAntiphon)
        {
            return [BuildMarianAntiphonStep(seasonalAntiphon, languageCode)];
        }

        if (entry.Kind == CustomDevotionStep.SpecialKind.MarianAntiphon)
        {
            // Option-selected antiphon (the Rosary): the named choice's value is an antiphon
            // id, "seasonal" (calendar-resolved) or "none" (no step).
            var value = entry.OptionKey is { } optionKey
                ? optionValues?.GetValueOrDefault(optionKey) ?? "seasonal"
                : "seasonal";
            if (!Enum.TryParse<MarianAntiphonOption>(value, ignoreCase: true, out var chosen)
                || chosen == MarianAntiphonOption.None)
            {
                return [];
            }

            var antiphon = chosen == MarianAntiphonOption.Seasonal ? seasonalAntiphon : chosen;
            return [BuildMarianAntiphonStep(antiphon, languageCode)];
        }

        var title = entry.TitleKey is { } titleKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, titleKey)
            : entry.Title ?? string.Empty;
        var subtitle = entry.SubtitleKey is { } subtitleKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, subtitleKey)
            : entry.Subtitle;
        var body = entry.BodyKey is { } bodyKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, bodyKey)
            : string.Empty;

        var isScripture = (languageCode is { } lang && entry.IsScriptureByLanguage?.TryGetValue(lang, out var perLanguage) == true
            ? perLanguage
            : entry.IsScripture) ?? false;
        var acclamation = entry.AcclamationKey is { } acclamationKey
            ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, acclamationKey)
            : null;
        var transliteratedBody = entry.BodyKey is { } bodyKeyForTranslit
            ? PrayerPackStore.Transliteration(bundleId, languageCode, bodyKeyForTranslit)
            : null;
        if (entry.Repeat is not { } count || count <= 1)
        {
            return [new RosaryStep(title, subtitle, body, Acclamation: acclamation, IsScripture: isScripture,
                TransliteratedBody: transliteratedBody, ImageOverrideKey: entry.ImageKey)];
        }

        return Enumerable.Range(1, count)
            .Select(h => new RosaryStep(
                $"{title} {Counter(h, count, languageCode)}", subtitle, body,
                Acclamation: acclamation, IsScripture: isScripture,
                TransliteratedBody: transliteratedBody, ImageOverrideKey: entry.ImageKey))
            .ToList();
    }

    /// <summary>The decade/bead-structured generic builder ("rosary" type) — announcement →
    /// major → N minors (dense global DecadeIndex, HailMaryIndexInDecade on minors only,
    /// "ordinal — title" subtitles), matching the retired hardcoded decade devotions' emission
    /// exactly so the bead track and step chrome behave identically everywhere.</summary>
    private static IReadOnlyList<RosaryStep> BuildCustomRosarySteps(
        CustomDevotionDefinition definition, string bundleId, string? languageCode, MarianAntiphonOption seasonalAntiphon,
        IReadOnlyDictionary<string, string>? optionValues = null, RosaryOptions? rosaryOptions = null,
        MysteryGroup todaysGroup = MysteryGroup.Joyful, string? variantId = null)
    {
        var form = definition.ResolvedRosary(variantId);
        if (form.Decades is not { } decades) return [];

        string Resolve(string key) => PrayerPackStore.ResolveBodyText(bundleId, languageCode, key);
        string FixedTitle(CustomDevotionDefinition.DecadesDefinition.FixedStep step) =>
            step.TitleKey is { } key ? Resolve(key) : step.Title ?? string.Empty;

        var steps = new List<RosaryStep>();
        foreach (var entry in form.Opening)
        {
            steps.AddRange(Expand(entry, bundleId, languageCode, seasonalAntiphon, optionValues));
        }

        if (decades.Source == "mysteryGroups")
        {
            steps.AddRange(BuildMysteryGroupDecades(
                decades, bundleId, languageCode, optionValues, rosaryOptions ?? new RosaryOptions(), todaysGroup));
        }
        else
        {
            var fruitLabel = PrayerTranslations.Get(languageCode, PrayerKey.FructusMysteriiLabel);
            var majorBody = Resolve(decades.MajorStep.BodyKey);
            var minorBody = Resolve(decades.MinorStep.BodyKey);
            var decadeCount = decades.Entries?.Count ?? decades.Count ?? 0;

            for (var d = 0; d < decadeCount; d++)
            {
                var entry = decades.Entries?[d];
                var imageKey = entry?.ImageKey ?? decades.FixedImageKey;
                var ordinalLabel = DecadeOrdinal(d, decades, bundleId, languageCode);
                var decadeSubtitle = ordinalLabel;

                // Said before the sorrow is named, not after its beads — see the format's
                // decades.preAnnouncement. Carries the decade's subtitle so the chrome reads as
                // part of that decade, but no DecadeIndex: it is not a bead.
                foreach (var pre in decades.PreAnnouncement ?? [])
                {
                    foreach (var step in Expand(pre, bundleId, languageCode, seasonalAntiphon, optionValues))
                    {
                        steps.Add(step with { Subtitle = step.Subtitle ?? decadeSubtitle });
                    }
                }

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

                steps.Add(new RosaryStep(FixedTitle(decades.MajorStep), decadeSubtitle, majorBody,
                    DecadeIndex: d, ImageOverrideKey: decades.MajorStep.ImageKey ?? imageKey));

                for (var h = 1; h <= decades.MinorCount; h++)
                {
                    steps.Add(new RosaryStep(
                        $"{FixedTitle(decades.MinorStep)} {Counter(h, decades.MinorCount, languageCode)}", decadeSubtitle, minorBody,
                        DecadeIndex: d, HailMaryIndexInDecade: h, ImageOverrideKey: imageKey));
                }

                steps.AddRange(PostMinorSteps(decades, bundleId, languageCode, optionValues, decadeSubtitle, d));
            }
        }

        foreach (var entry in form.Closing)
        {
            steps.AddRange(Expand(entry, bundleId, languageCode, seasonalAntiphon, optionValues));
        }

        return steps;
    }

    /// <summary>The Rosary's decade section — driven by the bundle's decades block but cataloged
    /// by the mystery-group machinery (<c>source: "mysteryGroups"</c>: selection mode +
    /// liturgical calendar) instead of bundle entries. Reproduces the retired hardcoded builder
    /// byte-for-byte: real <see cref="Mystery"/> values on announcement/minor steps (no image
    /// overrides), group-labelled ordinals when multiple groups are prayed, the single-mystery
    /// mode's true ordinal, and presenter mode's combined minors step with
    /// HailMaryIndexInDecade = MinorCount for the bead track.</summary>
    private static IReadOnlyList<RosaryStep> BuildMysteryGroupDecades(
        CustomDevotionDefinition.DecadesDefinition decades, string bundleId, string? languageCode,
        IReadOnlyDictionary<string, string>? optionValues, RosaryOptions rosary, MysteryGroup todaysGroup)
    {
        string Resolve(string key) => PrayerPackStore.ResolveBodyText(bundleId, languageCode, key);
        string FixedTitle(CustomDevotionDefinition.DecadesDefinition.FixedStep step) =>
            step.TitleKey is { } key ? Resolve(key) : step.Title ?? string.Empty;

        // The alternate-artwork seam: an eastern-style favorite stamps every Mystery-carrying step
        // with the parallel "eastern_" image key, leaving Mystery.ImageKey (identity + translation
        // lookup) untouched.
        string? VariantKey(Mystery mystery) =>
            rosary.MysteryImageStyle == MysteryImageStyle.Eastern ? $"eastern_{mystery.ImageKey}" : null;

        var groups = ResolveMysteryGroups(rosary, todaysGroup);
        var fruitLabel = PrayerTranslations.Get(languageCode, PrayerKey.FructusMysteriiLabel);
        var majorBody = Resolve(decades.MajorStep.BodyKey);
        var minorBody = Resolve(decades.MinorStep.BodyKey);
        var presenterOn = optionValues?.GetValueOrDefault("presenterMode") == "true";
        var showGroupName = groups.Count > 1;

        var steps = new List<RosaryStep>();
        var decadeIndex = 0;
        foreach (var group in groups)
        {
            var mysteries = MysteryCatalog.ForGroup(group);
            IEnumerable<int> indices = rosary.MysterySelectionMode == MysterySelectionMode.SingleMystery
                ? [rosary.SpecificMysteryOrder - 1]
                : Enumerable.Range(0, mysteries.Count);

            foreach (var d in indices)
            {
                var mystery = mysteries[d];
                var mysteryText = MysteryTranslations.Get(languageCode, mystery.ImageKey);
                var ordinalLabel = showGroupName
                    // The group prefix is still English — MysteryGroup has no
                    // per-prayer-language name yet.
                    ? $"{group} — {DecadeOrdinal(d, decades, bundleId, languageCode)}"
                    : DecadeOrdinal(d, decades, bundleId, languageCode);
                var decadeSubtitle = $"{ordinalLabel} — {mysteryText.Title}";

                steps.Add(new RosaryStep(mysteryText.Title, ordinalLabel,
                    $"{mysteryText.Description}\n\n{fruitLabel}: {mysteryText.Fruit}",
                    mystery, IsScripture: true, DecadeIndex: decadeIndex) { ImageVariantKey = VariantKey(mystery) });
                steps.Add(new RosaryStep(FixedTitle(decades.MajorStep), decadeSubtitle, majorBody,
                    DecadeIndex: decadeIndex, ImageOverrideKey: decades.MajorStep.ImageKey));

                if (presenterOn && decades.Presenter is { } presenter)
                {
                    steps.Add(new RosaryStep(presenter.CombinedTitleKey is { } ck ? Resolve(ck) : presenter.CombinedTitle ?? string.Empty, decadeSubtitle,
                        string.Join("\n\n", presenter.BodyKeys.Select(Resolve)),
                        mystery, DecadeIndex: decadeIndex, HailMaryIndexInDecade: decades.MinorCount) { ImageVariantKey = VariantKey(mystery) });
                }
                else
                {
                    for (var h = 1; h <= decades.MinorCount; h++)
                    {
                        steps.Add(new RosaryStep(
                            $"{FixedTitle(decades.MinorStep)} {Counter(h, decades.MinorCount, languageCode)}", decadeSubtitle, minorBody,
                            mystery, DecadeIndex: decadeIndex, HailMaryIndexInDecade: h) { ImageVariantKey = VariantKey(mystery) });
                    }
                }

                steps.AddRange(PostMinorSteps(decades, bundleId, languageCode, optionValues, decadeSubtitle, decadeIndex));
                decadeIndex++;
            }
        }

        return steps;
    }

    /// <summary>Expands the decades' <c>postMinor</c> entries for one decade — the same option
    /// gating as <see cref="Expand"/>, but every emitted step carries the decade's
    /// subtitle and index (the Rosary's per-decade Glory Be / Fatima Prayer / eternal
    /// rest).</summary>
    private static IReadOnlyList<RosaryStep> PostMinorSteps(
        CustomDevotionDefinition.DecadesDefinition decades, string bundleId, string? languageCode,
        IReadOnlyDictionary<string, string>? optionValues, string decadeSubtitle, int decadeIndex)
    {
        var steps = new List<RosaryStep>();
        foreach (var entry in decades.PostMinor ?? [])
        {
            if (entry.If is { } condition
                && !EvaluateCondition(condition, optionValues ?? new Dictionary<string, string>()))
            {
                continue;
            }

            var title = entry.TitleKey is { } titleKey
                ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, titleKey)
                : entry.Title ?? string.Empty;
            var body = entry.BodyKey is { } bodyKey
                ? PrayerPackStore.ResolveBodyText(bundleId, languageCode, bodyKey)
                : string.Empty;
            steps.Add(new RosaryStep(title, decadeSubtitle, body,
                DecadeIndex: decadeIndex, ImageOverrideKey: entry.ImageKey));
        }

        return steps;
    }
}
