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
    public enum Script { Hebrew, Arabic, Syriac, Latin }

    /// <summary>The script most of a text's letters belong to. Counted rather than sampled: a
    /// citation line ("— ܡܬܝ 28:1-7") mixes digits and punctuation into every body.</summary>
    public static Script ScriptOf(string text)
    {
        int hebrew = 0, arabic = 0, syriac = 0, latin = 0;
        foreach (var ch in text ?? string.Empty)
        {
            int c = ch;
            if (c is >= 0x0590 and <= 0x05FF) hebrew++;
            else if (c is (>= 0x0600 and <= 0x06FF) or (>= 0x0750 and <= 0x077F)) arabic++;
            else if (c is (>= 0x0700 and <= 0x074F) or (>= 0x0860 and <= 0x086F)) syriac++;
            else if (c is (>= 0x0041 and <= 0x005A) or (>= 0x0061 and <= 0x007A)
                     or (>= 0x0370 and <= 0x03FF) or (>= 0x1F00 and <= 0x1FFF)) latin++;
        }
        var best = Script.Latin;
        var top = 0;
        foreach (var (count, script) in new[] { (hebrew, Script.Hebrew), (arabic, Script.Arabic),
                                                (syriac, Script.Syriac), (latin, Script.Latin) })
        {
            if (count > top) { top = count; best = script; }
        }
        return best;
    }

    /// <summary>Only ever reached through a transliteration: no language ships its own text in
    /// Syriac letters, because "arc" is Aramaic in Hebrew script. Without a face covering the
    /// block the toggle would draw a line of tofu, which is worse than not offering it.</summary>
    public const string SyriacFontFamily = "/Assets/Fonts/NotoSansSyriac-Variable.ttf#Noto Sans Syriac";
    private const string SyriacWesternFontFamily = "/Assets/Fonts/NotoSansSyriacWestern-Variable.ttf#Noto Sans Syriac Western";
    private const string SyriacEasternFontFamily = "/Assets/Fonts/NotoSansSyriacEastern-Variable.ttf#Noto Sans Syriac Eastern";

    /// <summary><paramref name="script"/> overrides what the language would imply — pass it when
    /// rendering a transliteration.</summary>
    public static string ResolveBodyFontFamily(string languageCode, bool isScripture, Script? script) =>
        script switch
        {
            Script.Syriac => AppSettings.SyriacTypeface switch
            {
                AppSettings.TypefaceWestern => SyriacWesternFontFamily,
                AppSettings.TypefaceEastern => SyriacEasternFontFamily,
                _ => SyriacFontFamily,
            },
            _ => ResolveBodyFontFamily(languageCode, isScripture),
        };

    public static string ResolveBodyFontFamily(string languageCode, bool isScripture) => (languageCode is not null ? Prosary.Models.LanguageCatalog.BaseLanguage(languageCode) ?? languageCode : languageCode) switch
    {
        "he" or "arc" => isScripture
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
        "ar" => isScripture
            ? "/Assets/Fonts/ScheherazadeNew-Regular.ttf#Scheherazade New"
            : "/Assets/Fonts/Amiri-Regular.ttf#Amiri",
        "la" or "en" when isScripture => "/Assets/Fonts/Cardo-Regular.ttf#Cardo",
        // Cambria ships with Windows by default — no embedding needed.
        _ => "Cambria",
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
    public static double ResolveBodyFontSize(string languageCode, bool isScripture, Script? script) =>
        script == Script.Syriac ? 19 : ResolveBodyFontSize(languageCode, isScripture);

    public static double ResolveBodyFontSize(string languageCode, bool isScripture) => (languageCode is not null ? Prosary.Models.LanguageCatalog.BaseLanguage(languageCode) ?? languageCode : languageCode) switch
    {
        "he" or "arc" => isScripture ? 16 : 21,
        "ar" => isScripture ? 16 : 18,
        "la" or "en" => isScripture ? 19 : 17,
        _ => 17
    };
}
