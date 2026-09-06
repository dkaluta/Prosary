namespace Prosary.Models;

/// <summary>A prayer language the app can display, independent of the device's own UI/system
/// language.</summary>
/// <param name="Code">Prayer-language identifier used as the key into the content layer's
/// translations.</param>
/// <param name="NativeName">The language's own name, in its own script (shown in pickers).</param>
/// <param name="IsRightToLeft">Whether prayer text in this language should be displayed
/// right-to-left.</param>
public sealed record LanguageOption(string Code, string NativeName, bool IsRightToLeft);

/// <summary>Languages available for prayer text. Latin is the default — it's the neutral fallback
/// every lookup falls back to if a translation is missing in the chosen language.</summary>
public static class LanguageCatalog
{
    /// <summary>Extract a language for picker/typography purposes. Content resolution treats
    /// Mission and Vicariate Hebrew as independently ordered traditions.</summary>
    public static string? BaseLanguage(string code)
    {
        var dash = code.IndexOf('-');
        return dash > 0 ? code[..dash] : null;
    }

    public const string DefaultCode = "la";
    /// <summary>Internal content bucket only; stored Vicariate selections remain "he".</summary>
    public const string VicariateContentCode = "he-x-vicariate";

    /// <summary>Sentinel stored in a favorite's LanguageCode meaning "follow the app-level default
    /// setting" (see <see cref="AppSettings.DefaultLanguageCode"/>).</summary>
    public const string DefaultSentinel = "";

    public static readonly IReadOnlyList<LanguageOption> All =
    [
        new("la", "Latina", false),
        new("en", "English", false),
        new("ar", "العربية", true),
        new("he", "עברית", true),
        new("he-x-gamliel", "עברית", true),
        // Aramaic in Hebrew script — the Aramaic-rite communities' liturgical language.
        new("arc", "ܐܪܡܐܝܬ / ארמית", true),
        // Greek: the language a great deal of the app's own Scripture and prayer was first
        // written in — the Creed, the Sub Tuum, the Jesus Prayer.
        new("el", "Ἑλληνικά", false),
        new("es", "Español", false),
        new("ru", "Русский", false),
        new("tl", "Tagalog", false),
        new("fr", "Français", false),
        new("it", "Italiano", false),
    ];

    public static readonly IReadOnlyList<LanguageOption> PickerOptions =
        All.Where(language => language.Code != "he-x-gamliel").ToList();

    public static string PickerLanguageCode(string raw) => raw == "he-x-gamliel" ? "he" : raw;

    public static string SelectingLanguage(string next, string current) =>
        next == "he" && PickerLanguageCode(current) == "he" ? current : next;

    /// <summary>Every stored fallback code has its own row. Unlike an ordinary language
    /// picker, this editor includes each Hebrew tradition so another language can sit between
    /// them. The existing localized tradition names distinguish their otherwise identical names.</summary>
    public static IReadOnlyList<LanguageOption> FallbackOptions => FallbackOrder.Select(code =>
    {
        var language = All.First(option => option.Code == code);
        var tradition = Rites(code).FirstOrDefault(option => option.Code == code);
        return tradition is null ? language
            : language with { NativeName = $"{language.NativeName} — {tradition.NativeName}" };
    }).ToList();

    /// <summary>One Hebrew language choice; the separately selected tradition keeps its
    /// historical raw content code, including for existing bundles and favorites.</summary>
    public static IReadOnlyList<LanguageOption> AvailableOptions(IEnumerable<string> declaredCodes)
    {
        var available = declaredCodes.Select(PickerLanguageCode).ToHashSet();
        return PickerOptions.Where(language => available.Contains(language.Code)).ToList();
    }

    public static IReadOnlyList<string> FallbackOrder
    {
        get
        {
            var known = All.Select(l => l.Code).ToHashSet();
            var result = AppSettings.LanguageFallbackOrder.Where(known.Contains).Distinct().ToList();
            var defaults = All.Select(l => l.Code).Where(c => c != DefaultCode).Append(DefaultCode);
            var missing = defaults.Where(c => !result.Contains(c)).ToList();
            // A saved order from before a language was added still keeps its final Latin
            // safety net last. An explicitly earlier Latin placement stays where the user put it.
            if (result.LastOrDefault() == DefaultCode)
                result.InsertRange(result.Count - 1, missing);
            else
                result.AddRange(missing);
            return result;
        }
    }

    public static IReadOnlyList<string> FallbackChain(string? requested)
    {
        var result = new List<string>();
        void Append(string? code)
        {
            if (string.IsNullOrEmpty(code) || result.Contains(code)) return;
            result.Add(code);
            if (code != "he-x-gamliel" && BaseLanguage(code) is { } baseCode && !result.Contains(baseCode))
                result.Add(baseCode);
        }
        Append(string.IsNullOrEmpty(requested) ? AppSettings.DefaultLanguageCode : requested);
        foreach (var code in FallbackOrder) Append(code);
        Append(DefaultCode);
        return result;
    }

    /// <summary>Keep tradition order while generic Hebrew content participates once, at the
    /// first Hebrew tradition encountered. A Mission miss never jumps ahead to the Vicariate.</summary>
    public static IReadOnlyList<string> ContentFallbackChain(string? requested)
    {
        var result = new List<string>();
        void Append(string code) { if (!result.Contains(code)) result.Add(code); }
        foreach (var code in FallbackChain(requested))
        {
            Append(code == "he" ? VicariateContentCode : code);
            if (code is "he" or "he-x-gamliel") Append("he");
        }
        return result;
    }

    /// <summary>The Hebrew prayer traditions appear separately from the single language choice.
    /// Their historical content codes remain unchanged for stored choices and fallback.</summary>
    public static IReadOnlyDictionary<string, IReadOnlyList<LanguageOption>> RitesByLanguage =>
        new Dictionary<string, IReadOnlyList<LanguageOption>>
        {
            ["he"] =
            [
                new("he", Localization.Loc.Tr("prayer_tradition_vicariate", "Saint James Vicariate"), true),
                // The Mission of St. Gamaliel's wording, sent by Erez 2026-08-05.
                new("he-x-gamliel", Localization.Loc.Tr("prayer_tradition_mission", "Mission of St. Gamaliel"), true),
            ],
        };

    /// <summary>The rites offered for a code's language — empty when there is only one way to
    /// pray it.</summary>
    public static IReadOnlyList<LanguageOption> Rites(string code) =>
        RitesByLanguage.GetValueOrDefault(BaseLanguage(code) ?? code) ?? [];

    public static LanguageOption Resolve(string? code)
    {
        if (code is null || code == DefaultSentinel)
        {
            return Option(AppSettings.DefaultLanguageCode);
        }

        return Option(code);
    }

    /// <summary>Resolves a stored code, which may name a rite ("he-x-gamliel") rather than a
    /// plain language — the rite keeps its own code so every lookup can overlay it on the
    /// base.</summary>
    private static LanguageOption Option(string? code)
    {
        if (All.FirstOrDefault(l => l.Code == code) is { } exact) return exact;
        if (code is not null && Rites(code).FirstOrDefault(r => r.Code == code) is { } rite)
        {
            // A rite carries its language's name in pickers; its own name belongs to the rite row.
            var language = All.FirstOrDefault(l => l.Code == (BaseLanguage(rite.Code) ?? rite.Code));
            if (language is not null)
            {
                return rite with { NativeName = language.NativeName };
            }
        }

        return All.FirstOrDefault(l => l.Code == code) ?? All.First(l => l.Code == DefaultCode);
    }
}
