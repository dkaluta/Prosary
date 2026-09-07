using Prosary.Models;

namespace Prosary.Localization;

/// <summary>User-confirmed Jaffa wording, applied only after a Vicariate source wins.
/// Canonical content and the source's pointed/unpointed style remain intact.</summary>
internal static class VicariatePrayerWording
{
    internal static string Apply(string text, string contentProbe)
    {
        if (!AppSettings.UseJaffaHailMaryWording || contentProbe != LanguageCatalog.VicariateContentCode)
            return text;
        return text.Replace("מְלֵאַת הַחֶסֶד", "בְּרוּכַת הַחֶסֶד", StringComparison.Ordinal)
            .Replace("מלאת החסד", "ברוכת החסד", StringComparison.Ordinal);
    }
}
