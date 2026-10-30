using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class HomeWidgetTests
{
    [Fact]
    public void SourceCardsPreserveEarlierRemovalsAndEmptyLayouts()
    {
        Assert.Empty(HomeWidgets.AddingSourceCards([]));
        Assert.Equal(["photo", "feast", "hymn", "tradition"], HomeWidgets.AddingSourceCards(["photo", "feast"]));
        Assert.Equal(["hymn", "photo", "tradition"], HomeWidgets.AddingSourceCards(["hymn", "photo"]));
    }

    [Fact]
    public void MissingLayoutGetsDefaultsWhileAnIntentionallyEmptyHomeStaysEmpty()
    {
        Assert.Equal(new[] { "readings", "torah", "popeIntention", "calendar", "reminders", "scripture", "feast", "hymn", "tradition", "reflection" }, HomeWidgets.Parse(null));
        Assert.Empty(HomeWidgets.Parse(""));
    }

    [Fact]
    public void DailyCardMigrationPreservesEmptyAndExistingOrderWithoutDuplicates()
    {
        Assert.Empty(HomeWidgets.AddingDailyCards([]));
        Assert.Equal(["photo", "readings", "torah", "feast", "reflection"], HomeWidgets.AddingDailyCards(["photo", "readings", "feast"]));
        Assert.Equal(["reflection", "torah", "photo"], HomeWidgets.AddingDailyCards(["reflection", "torah", "photo"]));
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

    [Fact]
    public void CardColorsRejectUnknownValuesAndDefaultResetPreservesOtherCards()
    {
        Assert.Empty(HomeWidgets.ParseColors("bad json"));
        Assert.Empty(HomeWidgets.ParseColors("null"));
        var colors = HomeWidgets.ParseColors("""{"readings":"blue","feast":"rose","photo":"default","torah":"purple","unknown":"green"}""");
        Assert.Equal(2, colors.Count);
        Assert.Equal("blue", colors["readings"]);
        var previous = AppSettings.HomeWidgetColors.ToDictionary(pair => pair.Key, pair => pair.Value);
        var order = AppSettings.HomeWidgetOrder.ToArray();
        try
        {
            AppSettings.SetHomeWidgetColor("readings", "gold");
            AppSettings.SetHomeWidgetColor("feast", "rose");
            AppSettings.SetHomeWidgetColor("readings", "default");
            Assert.False(AppSettings.HomeWidgetColors.ContainsKey("readings"));
            Assert.Equal("rose", AppSettings.HomeWidgetColors["feast"]);
            Assert.Equal(order, AppSettings.HomeWidgetOrder);
        }
        finally
        {
            foreach (var id in HomeWidgets.All) AppSettings.SetHomeWidgetColor(id, previous.GetValueOrDefault(id) ?? "default");
        }
    }
}
