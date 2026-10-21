using Prosary.Localization;

namespace Prosary.Models;

/// <summary>Hebrew option captions name the prayers in the Rosary's selected tradition.
/// Other interface languages keep their existing localized captions.</summary>
public static class RosaryOptionLabels
{
    private static string? HebrewRite(string? languageCode)
    {
        if (UiLanguageCatalog.Current != "he") return null;
        var chosen = LanguageCatalog.Resolve(languageCode).Code;
        return chosen is "he" or "he-x-gamliel"
            ? PrayerPackStore.EffectiveLanguage("rosary", chosen) : null;
    }

    private static string Title(string language, string key) =>
        PrayerPackStore.ResolveDisplayText("rosary", language, key);

    private static string Caption(string key, string english, string hebrew) =>
        Loc.Tr(key, UiLanguageCatalog.Current == "he" ? hebrew : english);

    public static string Creed(string? languageCode, bool picker = false)
    {
        var apostles = PrayerPackStore.HasApostlesCreed("rosary", languageCode);
        if (HebrewRite(languageCode) is { } language)
            return Title(language, apostles ? "symbolumApostolorumTitle" : "symbolumNicaenumTitle");
        return apostles ? Loc.Tr(picker ? "PickerApostlesCreed.Text" : "EdApostlesCreed.Text", "Apostles' Creed")
            : Loc.Tr("favorite_editor_nicene_creed", "Nicene Creed");
    }

    public static string OpeningPrayers(string? languageCode, bool picker = false) =>
        HebrewRite(languageCode) is { } language
            ? string.Format(Loc.Tr("rosary_opening_prayers_format", "“{0}” ו־3 “{1}” בפתיחה"),
                Title(language, "paterNosterTitle"), Title(language, "aveMariaTitle"))
            : Caption(picker ? "PickerOpeningPrayers.Text" : "EdOpeningPrayers.Text", "Opening Our Father & 3 Hail Marys", "תפילות פתיחה");

    public static string OpeningFatima(string? languageCode, bool picker = false) =>
        HebrewRite(languageCode) is { } language
            ? string.Format(Loc.Tr("rosary_opening_fatima_format", "“{0}” אחרי תפילת “{1}” הפותחת"),
                Title(language, "oratioFatimaeTitle"), Title(language, "gloriaPatriTitle"))
            : Caption(picker ? "PickerOpeningFatima.Text" : "EdOpeningFatima.Text", "Fatima Prayer after the opening Glory Be", "תפילת פאטימה הנוספת בפתיחה");

    public static string Fatima(string? languageCode, bool picker = false) =>
        HebrewRite(languageCode) is { } language
            ? string.Format(Loc.Tr("rosary_fatima_each_decade_format", "“{0}” בסוף כל רז"), Title(language, "oratioFatimaeTitle"))
            : Caption(picker ? "PickerFatima.Text" : "EdFatima.Text", "Fatima Prayer after each decade", "תפילת פאטימה בסוף כל רז");

    public static string PresenterHint(string? languageCode) =>
        HebrewRite(languageCode) is { } language
            ? string.Format(Loc.Tr("rosary_presenter_hint_format", "איחוד עשר תפילות “{0}” ותפילת “{1}” של כל רז למסך אחד — שימושי למי שמוביל תפילה בציבור בעל־פה."),
                Title(language, "aveMariaTitle"), Title(language, "gloriaPatriTitle"))
            : Caption("EdPresenterHint.Text", "Combine each decade's Hail Marys and Glory Be onto one screen — useful when leading a group aloud from memory.",
                "איחוד התפילות החוזרות בכל רז למסך אחד — שימושי למי שמוביל תפילה בציבור בעל־פה.");

    public static string StMichael(string? languageCode, bool picker = false) =>
        HebrewRite(languageCode) is { } language ? Title(language, "sanctusMichaelTitle")
            : Loc.Tr(picker ? "PickerStMichael.Text" : "EdStMichael.Text", "St. Michael Prayer");

    public static string FinalSign(string? languageCode, bool picker = false) =>
        HebrewRite(languageCode) is { } language
            ? string.Format(Loc.Tr("rosary_final_sign_format", "{0} בסיום"), Title(language, "signumCrucisTitle"))
            : Loc.Tr(picker ? "PickerFinalCross.Text" : "EdFinalSign.Text", "Final Sign of the Cross");

    /// <summary>Generic Rosary option rows use the same captions as its native editor.</summary>
    public static string? CustomOption(string key, string? languageCode)
    {
        if (HebrewRite(languageCode) is not { } language) return null;
        return key switch
        {
            "apostlesCreed" => Creed(languageCode),
            "openingPrayers" => OpeningPrayers(languageCode),
            "openingFatimaPrayer" => OpeningFatima(languageCode),
            "fatimaPrayer" => Title(language, "oratioFatimaeTitle"),
            "stMichael" => StMichael(languageCode),
            "finalSignOfCross" => FinalSign(languageCode),
            _ => null,
        };
    }

    public static CustomDevotionOption WithAntiphonTitles(CustomDevotionOption option, string? languageCode)
    {
        if (option.Key != "antiphon" || option.Cases is null || HebrewRite(languageCode) is not { } language)
            return option;
        var keys = new HashSet<string>(StringComparer.Ordinal)
        {
            "salveRegina", "almaRedemptorisMater", "aveReginaCaelorum", "reginaCaeli", "subTuumPraesidium",
        };
        return option with
        {
            Cases = option.Cases.Select(choice => keys.Contains(choice.Id) ? choice with
            {
                NameByLanguage = new Dictionary<string, string>(choice.NameByLanguage ?? [])
                {
                    ["he"] = Title(language, choice.Id + "Title"),
                },
            } : choice).ToList(),
        };
    }
}
