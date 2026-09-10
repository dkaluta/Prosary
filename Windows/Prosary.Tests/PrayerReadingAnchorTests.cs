using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerReadingAnchorTests
{
    [Theory]
    [InlineData(0, 0)]
    [InlineData(19, 0)]
    [InlineData(20, 20)]
    [InlineData(65, 60)]
    public void ReadingAnchorStartsAtTheFirstSymbolOnTheVisibleLine(double top, int expected)
    {
        // Twenty symbols per 20px line: horizontal glyph positions are irrelevant, including
        // RTL lines and inline bold runs whose symbols still belong to the same text container.
        Assert.Equal(expected, PrayerReadingAnchor.FirstVisibleOffset(200, top, i => (i / 20 * 20, 20)));
    }

    [Fact]
    public void ReflowRetainsTheSameTextWhenArtworkMovesOutOfTheScrollView()
    {
        var anchor = new PrayerReadingAnchor(200, 0.25, 0);
        var narrowOffset = anchor.ScrollOffset(bodyTop: 400, lineTop: 200, lineHeight: 20, maximumOffset: 1500);
        var wideOffset = anchor.ScrollOffset(bodyTop: 70, lineTop: 100, lineHeight: 24, maximumOffset: 1000);
        Assert.Equal(605, narrowOffset);
        Assert.Equal(176, wideOffset);
        Assert.Equal(narrowOffset, anchor.ScrollOffset(400, 200, 20, 1500));
    }

    [Fact]
    public void TemporarilyNonScrollableLayoutDoesNotDiscardTheTextAnchor()
    {
        var anchor = new PrayerReadingAnchor(200, 0.25, 0);
        Assert.Equal(0, anchor.ScrollOffset(70, 100, 20, 0));
        Assert.Equal(605, anchor.ScrollOffset(400, 200, 20, 1500));
        Assert.Equal(200, anchor.TextOffset);
    }

    [Fact]
    public void IntroPositionAdaptsToTheNewArtworkAndHeaderHeight()
    {
        var anchor = PrayerReadingAnchor.BeforeBody(200, 400);
        Assert.Null(anchor.TextOffset);
        Assert.Equal(35, anchor.ScrollOffset(70, 0, 0, 1000));
        Assert.Equal(0, PrayerReadingAnchor.BeforeBody(0, 0).ScrollOffset(400, 0, 0, 1000));
    }
}
