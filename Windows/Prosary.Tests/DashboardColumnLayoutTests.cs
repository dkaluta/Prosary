using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class DashboardColumnLayoutTests
{
    [Fact]
    public void TwoColumnsFillTheShortestColumnInSavedOrder()
    {
        var layout = DashboardColumnLayout.Create(700, [400, 100, 80, 90]);
        Assert.Equal(2, layout.ColumnCount);
        Assert.Equal(new[] { 0d, 356, 356, 356 }, layout.Cards.Select(card => card.X));
        Assert.Equal(new[] { 0d, 0, 112, 204 }, layout.Cards.Select(card => card.Y));
        Assert.Equal(new[] { 400d, 100, 80, 90 }, layout.Cards.Select(card => card.Height));
        Assert.Equal(400, layout.Height);
    }

    [Fact]
    public void ThreeColumnsKeepNaturalHeightsAndChooseTheShortestColumn()
    {
        var layout = DashboardColumnLayout.Create(1100, [300, 40, 90, 20, 200, 80, 70]);
        Assert.Equal(3, layout.ColumnCount);
        Assert.Equal(new[] { 0d, 0, 0, 52, 84, 102, 194 }, layout.Cards.Select(card => card.Y));
        Assert.Equal(300, layout.Height);
        Assert.Equal(new[] { 0, 1, 2, 1, 1, 2, 2 }, layout.Cards.Select(card =>
            (int)Math.Round(card.X / (card.Width + DashboardColumnLayout.Gap))));
    }

    [Fact]
    public void AddingACardKeepsEarlierFramesAndMinimizesTheNewHeight()
    {
        var before = DashboardColumnLayout.Create(700, [400, 100, 80]);
        var after = DashboardColumnLayout.Create(700, [400, 100, 80, 90]);
        Assert.Equal(before.Cards, after.Cards.Take(3));
        Assert.Equal(204, after.Cards[3].Y);
        Assert.Equal(400, after.Height);
    }

    [Theory]
    [InlineData(339, 1)]
    [InlineData(691, 1)]
    [InlineData(692, 2)]
    [InlineData(1043, 2)]
    [InlineData(1044, 3)]
    [InlineData(2000, 3)]
    public void WidthBreakpointsRespectMinimumWidthAndMaximumContainer(double width, int columns)
    {
        var layout = DashboardColumnLayout.Create(width, [30, 40, 50, 60]);
        Assert.Equal(columns, layout.ColumnCount);
        Assert.True(layout.Width <= 1200);
        Assert.All(layout.Cards, card => Assert.True(card.X + card.Width <= layout.Width + 0.001));
        if (columns > 1) Assert.All(layout.Cards, card => Assert.True(card.Width >= 340));
    }

    [Fact]
    public void NarrowAndEmptyLayoutsHaveNoTrailingGapOrNegativeExtent()
    {
        var narrow = DashboardColumnLayout.Create(300, [100, 60]);
        Assert.Equal(new[] { 0d, 112 }, narrow.Cards.Select(card => card.Y));
        Assert.Equal(172, narrow.Height);
        Assert.Equal(0, DashboardColumnLayout.Create(900, []).Height);
        Assert.Equal(0, DashboardColumnLayout.Create(0, [100]).Cards[0].Width);
        Assert.Equal(340, DashboardColumnLayout.CardWidthFor(double.PositiveInfinity));
    }
}
