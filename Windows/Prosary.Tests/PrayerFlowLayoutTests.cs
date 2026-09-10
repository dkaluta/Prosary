using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerFlowLayoutTests
{
    [Theory]
    [InlineData(1, false, 20)]
    [InlineData(4, false, 98)]
    [InlineData(1, true, 61)]
    [InlineData(4, true, 139)]
    public void BeadBudgetIncludesEveryMysteryGroupAndVisibleDivider(int groups, bool minors, double width)
    {
        Assert.Equal(width, PrayerFlowLayout.BeadWidth(groups, true, minors, true));
        if (minors) Assert.Equal(width + 26, PrayerFlowLayout.BeadWidth(groups, true, true, false));
        Assert.Equal(0, PrayerFlowLayout.BeadWidth(groups, false, minors, true));
    }

    [Fact]
    public void WideLayoutAlwaysFitsTheMeasuredContentArea()
    {
        foreach (var width in new[] { 280d, 699, 819, 820, 833, 860, 1024, 1400 })
        foreach (var height in new[] { 0d, 180, 299, 300, 320, 600 })
        foreach (var groups in new[] { 0, 1, 3, 4, 8 })
        foreach (var showsBeads in new[] { false, true })
        {
            var layout = PrayerFlowLayout.Resolve(width, height, groups, showsBeads, true);
            if (!layout.IsWide) continue;
            var required = layout.ImageSide + 48 + 300
                + PrayerFlowLayout.BeadWidth(groups, showsBeads, true, layout.HasRoomForSingleMinorColumn);
            Assert.True(required <= width, $"{groups} groups need {required} at {width} × {height}");
            Assert.True(layout.ImageSide <= height);
        }
    }

    [Fact]
    public void WideSessionWithManyGroupsWaitsUntilEveryColumnFits()
    {
        Assert.False(PrayerFlowLayout.Resolve(900, 400, 8, true, true).IsWide);
        Assert.True(PrayerFlowLayout.Resolve(911, 400, 8, true, true).IsWide);
    }

    [Fact]
    public void ShortWindowShrinksArtworkAndSplitsMinorBeads()
    {
        var layout = PrayerFlowLayout.Resolve(820, 220, 4, true, true);
        Assert.True(layout.IsWide);
        Assert.False(layout.HasRoomForSingleMinorColumn);
        Assert.Equal(220, layout.ImageSide);
    }
}
