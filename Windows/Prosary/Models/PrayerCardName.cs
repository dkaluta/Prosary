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
        return Resolve(info.LocalizedDisplayName, info.DisplayNameInLanguage(LanguageCatalog.Resolve(prayerLanguage).Code),
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

    public static PrayerCardName ForBasicPrayer(BasicPrayer prayer, string? prayerLanguage)
    {
        var interfaceName = PrayerPackStore.ResolveDisplayText(prayer.BundleId, UiLanguageCatalog.Current, prayer.TitleKey);
        var prayerName = PrayerPackStore.ResolveDisplayText(prayer.BundleId, LanguageCatalog.Resolve(prayerLanguage).Code, prayer.TitleKey);
        return Resolve(interfaceName, prayerName, AppSettings.ShowPrayerNameInPrayerLanguage);
    }
}
