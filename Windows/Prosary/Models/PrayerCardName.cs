using Prosary.Localization;

namespace Prosary.Models;

/// <summary>Interface names are the default. Prayer-language names are an explicit card
/// preference and never replace a preset name or a devotion's descriptive status.</summary>
public sealed record PrayerCardName(string Title, string InterfaceSubtitle)
{
    public static PrayerCardName Resolve(string interfaceName, string prayerName, bool showPrayerLanguage)
    {
        var primary = HebrewDisplayText.WithoutMarks(showPrayerLanguage ? prayerName : interfaceName).Trim();
        var secondary = HebrewDisplayText.WithoutMarks(interfaceName).Trim();
        return new(primary, showPrayerLanguage && !string.Equals(primary, secondary, StringComparison.Ordinal)
            ? secondary : string.Empty);
    }

    public static PrayerCardName ForBundle(string bundleId, string? prayerLanguage = null)
    {
        var info = PrayerPackStore.Info(bundleId);
        if (info is null) return new(bundleId, "");
        var language = LanguageCatalog.Resolve(prayerLanguage).Code;
        if (LanguageCatalog.PickerLanguageCode(language) == "he")
            language = PrayerPackStore.EffectiveLanguage(bundleId, language);
        return Resolve(PrayerPackStore.InterfaceDisplayName(bundleId, language), info.DisplayNameInLanguage(language),
            AppSettings.ShowPrayerNameInPrayerLanguage);
    }

    public static PrayerCardName ForKind(PrayerKind kind, string? prayerLanguage = null)
    {
        if (kind == PrayerKind.Rosary && PrayerPackStore.Info("rosary") is not null)
            return ForBundle("rosary", prayerLanguage);
        var code = LanguageCatalog.Resolve(prayerLanguage).Code;
        var interfaceName = kind.DisplayName();
        var prayerName = kind == PrayerKind.JesusPrayer
            ? Loc.Tr("kind_jesus_prayer", interfaceName, LanguageCatalog.BaseLanguage(code) ?? code)
            : interfaceName;
        return Resolve(interfaceName, prayerName, AppSettings.ShowPrayerNameInPrayerLanguage);
    }

    // Basic prayers retain the chosen prayer/tradition heading even when the optional
    // interface subtitle is off. The directory and Pray pins share this policy.
    public static PrayerCardName ForBasicPrayer(BasicPrayer prayer, string? prayerLanguage,
        string? interfaceLanguage = null)
    {
        var language = BasicPrayerCatalog.EffectiveLanguage(prayer, prayerLanguage).Code;
        var interfaceCode = InterfaceTitleLanguage(interfaceLanguage ?? UiLanguageCatalog.Current, language);
        var interfaceName = PrayerPackStore.ResolveDisplayText(prayer.BundleId, interfaceCode, prayer.TitleKey);
        var prayerName = PrayerPackStore.ResolveDisplayText(prayer.BundleId, language, prayer.TitleKey);
        return new(prayerName, AppSettings.ShowPrayerNameInPrayerLanguage && prayerName != interfaceName
            ? interfaceName : string.Empty);
    }

    /// <summary>A Hebrew prayer name belongs to the active Hebrew tradition, including
    /// when it appears as interface text. Other interface languages keep their own names.</summary>
    internal static string InterfaceTitleLanguage(string interfaceLanguage, string effectivePrayerLanguage) =>
        UiLanguageCatalog.Normalize(interfaceLanguage) == "he" && effectivePrayerLanguage is "he" or "he-x-gamliel"
            ? effectivePrayerLanguage : interfaceLanguage;
}
