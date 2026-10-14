using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class CustomAccentTests
{
    [Theory]
    [InlineData(" #ab90cd ", "#AB90CD")]
    [InlineData("abc", "")]
    [InlineData("#00XX00", "")]
    [InlineData("##123456", "")]
    [InlineData("", "")]
    public void CustomColorUsesTheSharedOpaqueHexContract(string source, string expected) =>
        Assert.Equal(expected, AppColorPalette.NormalizeCustom(source));

    [Theory]
    [InlineData("FFFFFF")]
    [InlineData("000000")]
    [InlineData("00FF00")]
    [InlineData("FFCC00")]
    [InlineData("777777")]
    public void CustomControlsKeepReadableContrastInBothNativeThemes(string hex)
    {
        var color = AppColorPalette.Parse(hex);
        Assert.True(AppColorPalette.Contrast(AppColorPalette.AccessibleAccent(color, false), AppColorPalette.Parse("FFFFFF")) >= 4.5);
        Assert.True(AppColorPalette.Contrast(AppColorPalette.AccessibleAccent(color, true), AppColorPalette.Parse("2B2B2B")) >= 4.5);
    }

    [Fact]
    public void ACustomAccentDoesNotReplaceTheAppIconChoice()
    {
        var previousColor = AppSettings.AppColor;
        var previousAccent = AppSettings.CustomAccentColorHex;
        try
        {
            AppSettings.SetAppColor("rose");
            AppSettings.SetCustomAccentColorHex("#123456");
            Assert.Equal("rose", AppSettings.AppColor);
            Assert.Equal("#123456", AppSettings.CustomAccentColorHex);
            AppSettings.SetCustomAccentColorHex("");
            Assert.Equal(AppColorPalette.Resolve("rose").Accent(false), AppColorPalette.Accent("rose", "", false));
        }
        finally { AppSettings.SetAppColor(previousColor); AppSettings.SetCustomAccentColorHex(previousAccent); }
    }
}
