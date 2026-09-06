using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class PrayerTypographyTests
{
    [Theory]
    [InlineData("ܐܒܘܢ ܕܒܫܡܝܐ — 123", PrayerTypography.Script.Syriac)]
    [InlineData("אבון דבשמיא", PrayerTypography.Script.Hebrew)]
    [InlineData("Господи Иисусе Христе", PrayerTypography.Script.Cyrillic)]
    [InlineData("Κύριε ἐλέησον", PrayerTypography.Script.Greek)]
    [InlineData("أبانا الذي في السماوات", PrayerTypography.Script.Arabic)]
    [InlineData("\uFB2A\uFB2B\uFB35", PrayerTypography.Script.Hebrew)]
    [InlineData("\uFDF2\uFE8D\u08A0", PrayerTypography.Script.Arabic)]
    [InlineData("ééé אֱֽ֑֤֖֗֙", PrayerTypography.Script.Latin)]
    [InlineData("123 — **", PrayerTypography.Script.Latin)]
    public void DominantLettersDetermineScript(string body, PrayerTypography.Script script) =>
        Assert.Equal(script, PrayerTypography.ScriptOf(body));

    [Fact]
    public void ActualScriptOverridesSessionLanguageAndPreferencesNotify()
    {
        var notifications = 0;
        void Changed() => notifications++;
        AppSettings.TypographyChanged += Changed;
        try
        {
            AppSettings.SetSyriacTypeface(AppSettings.TypefaceWestern);
            Assert.Contains("Western", PrayerTypography.ResolveBodyFontFamily("arc", false, PrayerTypography.ScriptOf("ܐܒܘܢ")));
            AppSettings.SetSyriacTypeface(AppSettings.TypefaceEastern);
            Assert.Contains("Eastern", PrayerTypography.ResolveBodyFontFamily("arc", false, PrayerTypography.ScriptOf("ܐܒܘܢ")));
            Assert.Contains("FrankRuhlLibre", PrayerTypography.ResolveBodyFontFamily("arc", false, PrayerTypography.ScriptOf("אבון")));
            AppSettings.SetLatinPrayerTypeface(AppSettings.TypefaceSansSerif);
            Assert.Equal("Segoe UI", PrayerTypography.ResolveBodyFontFamily("arc", false, PrayerTypography.ScriptOf("Notre Père")));
            Assert.Equal("Cambria", PrayerTypography.ResolveBodyFontFamily("en", false, PrayerTypography.ScriptOf("Отче наш")));
            AppSettings.SetCyrillicPrayerTypeface(AppSettings.TypefaceSansSerif);
            Assert.Equal("Segoe UI", PrayerTypography.ResolveBodyFontFamily("en", false, PrayerTypography.ScriptOf("Отче наш")));
            Assert.Equal("Cambria", PrayerTypography.ResolveBodyFontFamily("ru", true, PrayerTypography.Script.Cyrillic));
            Assert.Equal("Cambria", PrayerTypography.ResolveBodyFontFamily("el", false, PrayerTypography.Script.Greek));
            Assert.Contains("Cardo", PrayerTypography.ResolveBodyFontFamily("el", true, PrayerTypography.Script.Greek));
            Assert.Contains("Cardo", PrayerTypography.ResolveBodyFontFamily("fr", true, PrayerTypography.Script.Latin));
            Assert.Contains("Shofar", PrayerTypography.ResolveBodyFontFamily("en", true, PrayerTypography.Script.Hebrew));
            Assert.Equal(4, notifications);
        }
        finally
        {
            AppSettings.TypographyChanged -= Changed;
            AppSettings.SetSyriacTypeface(AppSettings.TypefaceDefault);
            AppSettings.SetLatinPrayerTypeface(AppSettings.TypefaceDefault);
            AppSettings.SetCyrillicPrayerTypeface(AppSettings.TypefaceDefault);
        }
    }

    [Fact]
    public void RtlNavigationReversesGlyphsWithoutReversingActions()
    {
        Assert.Equal("⏮", PrayerNavigation.PreviousGlyph(false));
        Assert.Equal("⏭", PrayerNavigation.PreviousGlyph(true));
        Assert.Equal("⏭", PrayerNavigation.NextGlyph(false));
        Assert.Equal("⏮", PrayerNavigation.NextGlyph(true));
    }
}
