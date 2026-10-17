using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class DashboardColumnLayoutTests
{
    [Fact]
    public void TwoColumnsAdvanceIndependentlyWithoutShortestColumnReordering()
    {
        var layout = DashboardColumnLayout.Create(700, [400, 100, 80, 90]);
        Assert.Equal(2, layout.ColumnCount);
        Assert.Equal(new[] { 0d, 356, 0, 356 }, layout.Cards.Select(card => card.X));
        Assert.Equal(new[] { 0d, 0, 412, 112 }, layout.Cards.Select(card => card.Y));
        Assert.Equal(new[] { 400d, 100, 80, 90 }, layout.Cards.Select(card => card.Height));
        Assert.Equal(492, layout.Height);
    }

    [Fact]
    public void ThreeColumnsKeepSavedRoundRobinOrderAndNaturalHeights()
    {
        var layout = DashboardColumnLayout.Create(1100, [300, 40, 90, 20, 200, 80, 70]);
        Assert.Equal(3, layout.ColumnCount);
        Assert.Equal(new[] { 0d, 0, 0, 312, 52, 102, 344 }, layout.Cards.Select(card => card.Y));
        Assert.Equal(414, layout.Height);
        for (var index = 0; index < layout.Cards.Count; index++)
            Assert.Equal(index % 3 * (layout.Cards[index].Width + DashboardColumnLayout.Gap), layout.Cards[index].X);
    }

    [Fact]
    public void ExpandingACardOnlyMovesLaterCardsInItsOwnColumn()
    {
        var compact = DashboardColumnLayout.Create(700, [40, 100, 80, 90]);
        var expanded = DashboardColumnLayout.Create(700, [400, 100, 80, 90]);
        Assert.Equal(compact.Cards[1], expanded.Cards[1]);
        Assert.Equal(compact.Cards[3], expanded.Cards[3]);
        Assert.Equal(360, expanded.Cards[2].Y - compact.Cards[2].Y);
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
