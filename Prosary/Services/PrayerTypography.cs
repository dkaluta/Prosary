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
    public static string ResolveBodyFontFamily(string languageCode, bool isScripture) => languageCode switch
    {
        "he" => isScripture
            ? "/Assets/Fonts/ShofarRegular.ttf#Shofar"
            : "/Assets/Fonts/FrankRuhlLibre-Variable.ttf#Frank Ruhl Libre",
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
    public static double ResolveBodyFontSize(string languageCode, bool isScripture) => languageCode switch
    {
        "he" => isScripture ? 16 : 21,
        "ar" => isScripture ? 16 : 18,
        "la" or "en" => isScripture ? 19 : 17,
        _ => 17
    };
}
