using System.Globalization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>
/// Resolves the serif typeface and size for prayer/Scripture body text, per language — factored
/// out of irosary's <c>RosaryViewModel.ResolveBodyFontFamily</c>/<c>ResolveBodyFontSize</c>
/// (previously duplicated inline in a single ViewModel) into one shared helper the Rosary,
/// Angelus, and Jesus Prayer flows can all call, matching iOS's shared
/// <c>Typography/PrayerTypography.swift</c>.
///
/// Windows-only now, so this collapses irosary's per-platform branching (which had an Apple-only
/// native-serif path via <c>SystemSerifLabel</c>) down to the single WinUI3 case it already had
/// as its Windows fallback.
/// </summary>
public static class PrayerTypography
{
    /// <summary>WinUI's native, language-aware UI font token. Keep this as plain binding data:
    /// resolving FontFamily.XamlAutoFontFamily here would activate XAML while constructing or
    /// loading a ViewModel, before a UI thread necessarily exists. The TextBlock resolves the
    /// token on its own UI thread, retaining the platform's native font selection.</summary>
    public const string NativeUiFontFamily = "XamlAutoFontFamily";

    // Scripture quotations (the mystery-announcement step) get a dedicated typeface distinct
    // from ordinary prayer text, uniformly across platforms — Cardo (Latin) and Scheherazade New
    // (Arabic) were both designed for classical/Biblical typesetting, the same reasoning behind
    // using Shofar (rather than Frank Ruhl Libre) for Hebrew Scripture.
    //
    // Font family names below are the embedded fonts' own internal family names (via the
    // ms-appx:///Assets/Fonts/{file}#{family name} URI syntax WinUI3 uses for bundled,
    // non-installed fonts) — NOT yet verified against a real Windows build from this environment;
    // check these resolve correctly on first run and adjust the #-suffix if a font falls back to
    // the default UI font.
    /// <summary>The writing system a run of text is actually in.
    ///
    /// Nearly always this follows from the language. The exception is a transliteration, which
    /// is *by definition* in a different script from its own language's — and the bundle format
    /// deliberately leaves which script to the author (Hebrew letters for Tagalog, Syriac
    /// letters for Aramaic). So rather than have the format declare it and risk the declaration
    /// drifting from the text, it is read off the characters, which cannot disagree with
    /// themselves.</summary>
    public enum Script { Hebrew, Arabic, Syriac, Cyrillic, Greek, Latin }

    /// <summary>The script most of a text's letters belong to. Counted rather than sampled: a
    /// citation line ("— ܡܬܝ 28:1–7") mixes digits and punctuation into every body.</summary>
    public static Script ScriptOf(string text)
    {
        int hebrew = 0, arabic = 0, syriac = 0, cyrillic = 0, greek = 0, latin = 0;
        foreach (var ch in text ?? string.Empty)
        {
            if (!char.IsLetter(ch)) continue;
            int c = ch;
            if (c is (>= 0x0590 and <= 0x05FF) or (>= 0xFB1D and <= 0xFB4F)) hebrew++;
            else if (c is (>= 0x0600 and <= 0x06FF) or (>= 0x0750 and <= 0x077F)
                     or (>= 0x0870 and <= 0x08FF) or (>= 0xFB50 and <= 0xFDFF)
                     or (>= 0xFE70 and <= 0xFEFF)) arabic++;
            else if (c is (>= 0x0700 and <= 0x074F) or (>= 0x0860 and <= 0x086F)) syriac++;
            else if (c is (>= 0x0400 and <= 0x052F) or (>= 0x1C80 and <= 0x1C8F)
                     or (>= 0x2DE0 and <= 0x2DFF) or (>= 0xA640 and <= 0xA69F)) cyrillic++;
            else if (c is (>= 0x0370 and <= 0x03FF) or (>= 0x1F00 and <= 0x1FFF)) greek++;
            else if (c is (>= 0x0041 and <= 0x005A) or (>= 0x0061 and <= 0x007A)
                     or (>= 0x00C0 and <= 0x024F) or (>= 0x1E00 and <= 0x1EFF)) latin++;
        }
        var best = Script.Latin;
        var top = 0;
        foreach (var (count, script) in new[] { (hebrew, Script.Hebrew), (arabic, Script.Arabic),
                                                (syriac, Script.Syriac), (cyrillic, Script.Cyrillic),
                                                (greek, Script.Greek), (latin, Script.Latin) })
        {
            if (count > top) { top = count; best = script; }
        }
        return best;
    }

    /// <summary>Syriac covers both ordinary imported text and reading aids.</summary>
    public const string SyriacFontFamily = "/Assets/Fonts/NotoSansSyriac-Variable.ttf#Noto Sans Syriac";
    private const string SyriacWesternFontFamily = "/Assets/Fonts/NotoSansSyriacWestern-Variable.ttf#Noto Sans Syriac Western";
    private const string SyriacEasternFontFamily = "/Assets/Fonts/NotoSansSyriacEastern-Variable.ttf#Noto Sans Syriac Eastern";

    public static bool IsRightToLeft(Script script) => script is Script.Hebrew or Script.Arabic or Script.Syriac;

    private static Script LanguageScript(string? code) =>
        (code is null ? null : LanguageCatalog.BaseLanguage(code) ?? code) switch
        {
            "he" or "arc" => Script.Hebrew,
            "ar" => Script.Arabic,
            "ru" => Script.Cyrillic,
            "el" => Script.Greek,
            _ => Script.Latin,
        };

    public static string ResolveBodyFontFamily(string? languageCode, bool isScripture, Script? script = null) =>
        (script ?? LanguageScript(languageCode)) switch
        {
            Script.Syriac => AppSettings.SyriacTypeface switch
            {
                AppSettings.TypefaceWestern => SyriacWesternFontFamily,
                AppSettings.TypefaceEastern => SyriacEasternFontFamily,
                _ => SyriacFontFamily,
            },
            Script.Hebrew => isScripture
                ? AppSettings.HebrewScriptureTypeface switch
                {
                    AppSettings.TypefaceStamAshkenaz => "/Assets/Fonts/StamAshkenazCLM.ttf#Stam Ashkenaz CLM",
                    AppSettings.TypefaceStamSefarad => "/Assets/Fonts/StamSefaradCLM.ttf#Stam Sefarad CLM",
                    AppSettings.TypefaceRashi => "/Assets/Fonts/NotoRashiHebrew-Variable.ttf#Noto Rashi Hebrew",
                    _ => "/Assets/Fonts/ShofarRegular.ttf#Shofar",
                }
                : AppSettings.HebrewPrayerTypeface switch
                {
                    AppSettings.TypefaceDavidLibre => "/Assets/Fonts/DavidLibre-Regular.ttf#David Libre",
                    AppSettings.TypefaceSansSerif => "Segoe UI",
                    _ => "/Assets/Fonts/FrankRuhlLibre-Variable.ttf#Frank Ruhl Libre",
                },
            Script.Arabic => isScripture
                ? "/Assets/Fonts/ScheherazadeNew-Regular.ttf#Scheherazade New"
                : "/Assets/Fonts/Amiri-Regular.ttf#Amiri",
            Script.Cyrillic when isScripture => "Cambria",
            Script.Cyrillic => AppSettings.CyrillicPrayerTypeface == AppSettings.TypefaceSansSerif ? "Segoe UI" : "Cambria",
            Script.Latin or Script.Greek when isScripture => "/Assets/Fonts/Cardo-Regular.ttf#Cardo",
            Script.Greek => "Cambria",
            _ => AppSettings.LatinPrayerTypeface == AppSettings.TypefaceSansSerif ? "Segoe UI" : "Cambria",
        };

    // Matches iOS/Android's own per-language/content-type point sizes exactly (16/21 Hebrew
    // Scripture/prayer, 16/18 Arabic Scripture/prayer, 19/17 Latin+English Scripture/prayer) —
    // this project's original version collapsed all six cases down to just two values (21/18),
    // which wasn't just a rough approximation but a real mismatch on four of the six.
    //
    // Deliberately NOT scaled down for desktop the way iOS's own PrayerTypography.swift scales
    // these same numbers by 0.76 on its macOS/Catalyst build: WinUI3's effective-pixel unit isn't
    // the same as an Apple point (that 0.76 correction is tuned specifically for macOS's own,
    // much smaller, native body-text convention), and applying it here made every prayer read as
    // noticeably smaller than this app's own button/caption text — the opposite problem. Android's
    // own PrayerTypography.kt uses these exact numbers with no correction at all and never needed
    // one, which is the closer precedent for a platform with no special desktop-only type ramp.
    public static double ResolveBodyFontSize(string? languageCode, bool isScripture, Script? script = null) =>
        (script ?? LanguageScript(languageCode)) switch
        {
            Script.Syriac => 19,
            Script.Hebrew => isScripture ? 16 : 21,
            Script.Arabic => isScripture ? 16 : 18,
            Script.Latin or Script.Greek => isScripture ? 19 : 17,
            _ => 17,
        };
}
