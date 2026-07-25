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

    // Frank Ruhl Libre (Hebrew prayers) and Cardo (Latin/English Scripture) read a touch smaller
    // than the system serifs at the same point size — bumped up slightly to match. Shofar
    // (Hebrew Scripture) is fine as-is at the base size.
    public static double ResolveBodyFontSize(string languageCode, bool isScripture) => languageCode switch
    {
        "he" when !isScripture => 21,
        "la" or "en" when isScripture => 21,
        _ => 18,
    };
}
