using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class BibleBookPaginationTests
{
    [Fact]
    public void FacingPagesRequireTwoReadableColumnsAndUsableHeight()
    {
        Assert.False(BibleBookPagination.SupportsFacingPages(719, 600));
        Assert.False(BibleBookPagination.SupportsFacingPages(900, 359));
        Assert.True(BibleBookPagination.SupportsFacingPages(720, 360));
    }

    [Fact]
    public void PagesKeepEveryWholeSourceBlockInPhysicalOrder()
    {
        var pages = BibleBookPagination.Paginate([80, 90, 40, 120, 20], 200);
        Assert.Equal(new[] { new BibleBookPage(0, 2), new(2, 3) }, pages);
        Assert.Equal(Enumerable.Range(0, 5), pages.SelectMany(page => Enumerable.Range(page.Start, page.Count)));
    }

    [Fact]
    public void LongBlockRemainsWholeOnItsOwnScrollablePage()
    {
        var pages = BibleBookPagination.Paginate([40, 900, 50, 60], 200);
        Assert.Equal(new[] { new BibleBookPage(0, 1), new(1, 1), new(2, 2) }, pages);
    }

    [Fact]
    public void CanonicalJumpAndResizeFindTheSpreadContainingTheSameBlock()
    {
        var narrowPages = BibleBookPagination.Paginate([100, 100, 100, 100, 100], 200);
        var tallPages = BibleBookPagination.Paginate([100, 100, 100, 100, 100], 400);
        Assert.Equal(2, BibleBookPagination.PageContaining(narrowPages, 4));
        Assert.Equal(2, BibleBookPagination.SpreadContaining(narrowPages, 4));
        Assert.Equal(1, BibleBookPagination.PageContaining(tallPages, 4));
        Assert.Equal(0, BibleBookPagination.SpreadContaining(tallPages, 4));
    }

    [Fact]
    public void MissingMeasurementCannotDropOrSplitSourceBlocks()
    {
        var pages = BibleBookPagination.Paginate([double.NaN, 20, double.PositiveInfinity], 200);
        Assert.Equal(Enumerable.Range(0, 3), pages.SelectMany(page => Enumerable.Range(page.Start, page.Count)));
        Assert.Empty(BibleBookPagination.Paginate([], 200));
    }

    [Theory]
    [InlineData(-80, false, 1)][InlineData(80, false, -1)]
    [InlineData(80, true, 1)][InlineData(-80, true, -1)]
    [InlineData(20, false, 0)][InlineData(-20, true, 0)]
    public void PageTurnsFollowScriptureDirection(double translation, bool scriptureRightToLeft, int expected) =>
        Assert.Equal(expected, BibleBookPagination.SwipeDirection(translation, scriptureRightToLeft));
    [Fact]
    public void FlowingParagraphsPreserveSourceOrderAndStopAtExceptionalUnits()
    {
        Assert.Equal(new[] { new BibleBookPage(0, 2), new(2, 1), new(3, 2), new(5, 1) },
            BibleBookPagination.Paragraphs(0, 6, [true, true, false, true, true, false]));
        var pages = BibleBookPagination.FlowPages(7, 100, (_, count) => ((count + 1) / 2) * 40);
        Assert.Equal(new[] { new BibleBookPage(0, 4), new(4, 3) }, pages);
        Assert.Equal(Enumerable.Range(0, 7), pages.SelectMany(page => Enumerable.Range(page.Start, page.Count)));
    }
}
