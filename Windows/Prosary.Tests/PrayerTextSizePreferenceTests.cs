using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerTextSizePreferenceTests
{
    [Theory]
    [InlineData("en", PrayerTypography.Script.Latin, 17d, 19d)]
    [InlineData("he", PrayerTypography.Script.Hebrew, 21d, 16d)]
    [InlineData("ar", PrayerTypography.Script.Arabic, 18d, 16d)]
    [InlineData("arc", PrayerTypography.Script.Syriac, 19d, 19d)]
    [InlineData("ru", PrayerTypography.Script.Cyrillic, 17d, 19d)]
    [InlineData("el", PrayerTypography.Script.Greek, 17d, 19d)]
    public void PrayerSizeChangesOrdinaryBodiesButPreservesScriptureAndTypeface(
        string language, PrayerTypography.Script script, double prayer, double scripture)
    {
        var previous = AppSettings.PrayerTextSizePercent;
        var family = PrayerTypography.ResolveBodyFontFamily(language, false, script);
        var heading = PrayerTypography.ResolveHeadingFontFamily("Heading");
        try
        {
            AppSettings.SetPrayerTextSizePercent(150);
            Assert.Equal(prayer * 1.5, PrayerTypography.ResolveBodyFontSize(language, false, script));
            Assert.Equal(scripture, PrayerTypography.ResolveBodyFontSize(language, true, script));
            Assert.Equal(family, PrayerTypography.ResolveBodyFontFamily(language, false, script));
            Assert.Equal(heading, PrayerTypography.ResolveHeadingFontFamily("Heading"));
            AppSettings.SetPrayerTextSizePercent(80);
            Assert.Equal(prayer * .8, PrayerTypography.ResolveBodyFontSize(language, false, script), 6);
            Assert.Equal(scripture, PrayerTypography.ResolveBodyFontSize(language, true, script));
        }
        finally { AppSettings.SetPrayerTextSizePercent(previous); }
    }

    [Fact]
    public void InvalidStoredSizesAreClampedAndOpenReadersReceiveTypographyNotifications()
    {
        var previous = AppSettings.PrayerTextSizePercent;
        var changes = 0;
        void Changed() => changes++;
        AppSettings.TypographyChanged += Changed;
        try
        {
            AppSettings.SetPrayerTextSizePercent(-1);
            Assert.Equal(80, AppSettings.PrayerTextSizePercent);
            AppSettings.SetPrayerTextSizePercent(int.MaxValue);
            Assert.Equal(200, AppSettings.PrayerTextSizePercent);
            Assert.Equal(2, changes);
        }
        finally
        {
            AppSettings.TypographyChanged -= Changed;
            AppSettings.SetPrayerTextSizePercent(previous);
        }
    }

    [Fact]
    public void SettingsOfferTheSharedSizeChoicesAndUpdateTheExistingPreference()
    {
        var previous = AppSettings.PrayerTextSizePercent;
        try
        {
            AppSettings.SetPrayerTextSizePercent(100);
            var settings = new SettingsViewModel(0);
            Assert.Equal(new[] { 80, 90, 100, 110, 125, 150, 175, 200 }, settings.PrayerTextSizeOptions.Select(option => option.Percent));
            Assert.Equal(100, settings.SelectedPrayerTextSize.Percent);
            Assert.NotEmpty(settings.SelectedPrayerTextSize.Label);
            settings.SelectedPrayerTextSize = settings.PrayerTextSizeOptions.Single(option => option.Percent == 175);
            Assert.Equal(175, AppSettings.PrayerTextSizePercent);
        }
        finally { AppSettings.SetPrayerTextSizePercent(previous); }
    }
}
