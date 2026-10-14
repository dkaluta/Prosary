using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class HomeWidgetTests
{
    [Fact]
    public void MissingLayoutGetsDefaultsWhileAnIntentionallyEmptyHomeStaysEmpty()
    {
        Assert.Equal(new[] { "readings", "popeIntention", "calendar", "reminders", "scripture", "feast" }, HomeWidgets.Parse(null));
        Assert.Empty(HomeWidgets.Parse(""));
    }

    [Fact]
    public void RestoringALayoutIgnoresUnknownAndDuplicateCardsWithoutChangingItsOrder()
    {
        Assert.Equal(new[] { "photo", "readings", "reflection" },
            HomeWidgets.Parse("photo\nunknown\nreadings\nphoto\nreflection\n"));
    }

    [Fact]
    public void AddingACardAppendsItAndNeverRestoresRemovedCards()
    {
        Assert.Equal(new[] { "reflection", "photo" }, HomeWidgets.Add(["reflection"], "photo"));
        Assert.Equal(new[] { "photo" }, HomeWidgets.Add([], "photo"));
        Assert.Equal(new[] { "photo" }, HomeWidgets.Add(["photo"], "photo"));
        Assert.Empty(HomeWidgets.Add([], "unknown"));
    }

    [Fact]
    public void CollapsedCardsStartEmptyAndRejectUnknownAndRepeatedIdentifiers()
    {
        Assert.Empty(HomeWidgets.ParseCollapsed(null));
        Assert.Empty(HomeWidgets.ParseCollapsed(""));
        Assert.Equal(["photo", "scripture"], HomeWidgets.ParseCollapsed("photo\nunknown\nscripture\nphoto"));
    }

    [Fact]
    public void GraphicPathsRemainScopedToKnownCardsAndCorruptPreferencesStayEmpty()
    {
        Assert.Empty(HomeWidgets.ParseGraphics("bad json"));
        Assert.Empty(HomeWidgets.ParseGraphics("null"));
        var paths = HomeWidgets.ParseGraphics("""{"scripture":"/private/photo.png","unknown":"/another.png","calendar":""}""");
        Assert.Single(paths);
        Assert.Equal("/private/photo.png", paths["scripture"]);
    }
}
