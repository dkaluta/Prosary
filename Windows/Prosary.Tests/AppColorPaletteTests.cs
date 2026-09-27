using Prosary.Models;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class AppColorPaletteTests
{
    [Fact]
    public void SharedPaletteDefaultsToBlueAndRejectsUnknownValues()
    {
        Assert.Equal(new[] { "blue", "green", "red", "purple", "rose", "white", "gold" },
            AppColorPalette.All.Select(option => option.Id));
        Assert.Equal("blue", AppColorPalette.Resolve(null).Id);
        Assert.Equal("blue", AppColorPalette.Resolve("future-color").Id);
    }

    [Fact]
    public void AppearanceSelectionNotifiesOnceAndPersistsWhenReopened()
    {
        var previous = AppSettings.AppColor;
        var changes = 0;
        void Changed() => changes++;
        try
        {
            AppSettings.SetAppColor("blue");
            AppSettings.AppColorChanged += Changed;
            var appearance = new AppearanceViewModel();
            appearance.SelectedAppColor = appearance.AppColorOptions.Single(option => option.Id == "green");
            Assert.Equal("green", AppSettings.AppColor);
            Assert.Equal(1, changes);
            Assert.Equal("green", new AppearanceViewModel().SelectedAppColor.Id);
            Assert.Equal("green", Assert.Single(appearance.AppColorOptions, option => option.IsSelected).Id);
            Assert.All(appearance.AppColorOptions, option =>
                Assert.Equal($"ms-appx:///Assets/Icons/prosary-{option.Id}.ico", option.IconSource));
            AppSettings.SetAppColor("green");
            Assert.Equal(1, changes);

            var current = new BeadInfo { Kind = BeadKind.Decade, State = BeadState.Current };
            Assert.Equal(AppColorPalette.Resolve("green").Accent(false), current.Color);
            AppSettings.SetAppColor("invalid");
            Assert.Equal("blue", AppSettings.AppColor);
            Assert.Equal(AppColorPalette.Resolve("blue").Accent(false), current.Color);
        }
        finally
        {
            AppSettings.AppColorChanged -= Changed;
            AppSettings.SetAppColor(previous);
        }
    }

    [Fact]
    public void AppearanceTracksExternalColorChangesOnlyWhileActive()
    {
        var previous = AppSettings.AppColor;
        var appearance = new AppearanceViewModel();
        try
        {
            appearance.Activate();
            AppSettings.SetAppColor("red");
            Assert.Equal("red", appearance.SelectedAppColor.Id);
            Assert.Equal("red", Assert.Single(appearance.AppColorOptions, option => option.IsSelected).Id);
            appearance.Deactivate();
            AppSettings.SetAppColor("green");
            Assert.Equal("red", appearance.SelectedAppColor.Id);
            appearance.Activate();
            Assert.Equal("green", appearance.SelectedAppColor.Id);
        }
        finally
        {
            appearance.Deactivate();
            AppSettings.SetAppColor(previous);
        }
    }

    [Fact]
    public void AccentTextKeepsContrastInBothThemesAndIconsDoNotChangeWithTheme()
    {
        foreach (var option in AppColorPalette.All)
        {
            var light = option.Accent(false);
            var dark = option.Accent(true);
            Assert.True(Contrast(Luminance(light), 1) >= 4.5, option.Id);
            Assert.True(Contrast(Luminance(dark), Channel(32)) >= 4.5, option.Id);
            Assert.Equal($"prosary-{option.Id}.ico", option.IconFileName);
        }
    }

    private static double Luminance(Windows.UI.Color color) =>
        0.2126 * Channel(color.R) + 0.7152 * Channel(color.G) + 0.0722 * Channel(color.B);

    private static double Channel(byte component)
    {
        var value = component / 255.0;
        return value <= 0.04045 ? value / 12.92 : Math.Pow((value + 0.055) / 1.055, 2.4);
    }

    private static double Contrast(double a, double b) => (Math.Max(a, b) + 0.05) / (Math.Min(a, b) + 0.05);
}
