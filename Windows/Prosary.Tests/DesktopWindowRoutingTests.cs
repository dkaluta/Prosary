using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.Views;
using Xunit;

namespace Prosary.Tests;

public class DesktopWindowRoutingTests
{
    [Fact]
    public void SavedCopiesAndBasicPrayersHaveStableDistinctWindowIdentities()
    {
        var first = Guid.NewGuid();
        var second = Guid.NewGuid();
        Assert.Equal(DesktopPrayerIdentity.Saved(first), DesktopPrayerIdentity.Saved(first));
        Assert.NotEqual(DesktopPrayerIdentity.Saved(first), DesktopPrayerIdentity.Saved(second));
        Assert.NotEqual(DesktopPrayerIdentity.Saved(first), DesktopPrayerIdentity.Basic(first.ToString("D")));
        Assert.Equal(DesktopPrayerIdentity.Basic("hailMary"), DesktopPrayerIdentity.Basic("hailMary"));
        Assert.NotEqual(DesktopPrayerIdentity.Basic("hailMary"), DesktopPrayerIdentity.Basic("ourFather"));
    }

    [Fact]
    public void SavedFlowsUseTheirExplicitCopyAndCatalogFlowsStayUnsaved()
    {
        var id = Guid.NewGuid();
        Assert.Equal(id, DesktopWindowManager.SavedPrayerID(typeof(RosaryPrayerPage), id));
        Assert.Equal(id, DesktopWindowManager.SavedPrayerID(typeof(CustomDevotionFlowPage),
            new CustomDevotionFlowParams(id, "angelus")));
        Assert.Equal(id, DesktopWindowManager.SavedPrayerID(typeof(JesusPrayerFlowPage),
            new JesusPrayerFlowParams(id, null)));
        Assert.Null(DesktopWindowManager.SavedPrayerID(typeof(CustomDevotionFlowPage),
            new CustomDevotionFlowParams(null, "angelus")));
        Assert.Null(DesktopWindowManager.SavedPrayerID(typeof(BasicPrayerFlowPage), "hailMary"));
    }

    [Fact]
    public void DetachedCommandsNeverChooseAnotherWindowsFrame()
    {
        var navigation = WindowNavigation.Detached;
        Assert.Null(navigation.OwnerWindow);
        Assert.False(navigation.CanGoBack);
        navigation.Navigate<BasicPrayerFlowPage>("hailMary");
        navigation.Replace<BasicPrayerFlowPage>("ourFather");
        navigation.GoBack();
        navigation.PopToRoot();
        Assert.Null(navigation.OwnerWindow);
    }

    [Fact]
    public void DeletingOneCustomCopyClearsAllItsFormsAndDaysOnly()
    {
        string? json = null;
        var store = new LocalPrayerRunStore(() => json, value => json = value);
        var first = DesktopPrayerIdentity.DevotionID("novena", Guid.NewGuid());
        var second = DesktopPrayerIdentity.DevotionID("novena", Guid.NewGuid());
        var state = new PrayerRunState("signature", 3, "en", "2026-09-10");
        var firstStandard = PrayerRunKeys.Custom(first, "standard", 0);
        var firstOtherDay = PrayerRunKeys.Custom(first, "other", 4);
        var sibling = PrayerRunKeys.Custom(second, "standard", 0);
        var catalog = PrayerRunKeys.Custom("novena", "standard", 0);
        foreach (var key in new[] { firstStandard, firstOtherDay, sibling, catalog }) store.Save(key, state);

        store.RemovePrefix($"custom:{first}:");

        Assert.Null(store.Get(firstStandard));
        Assert.Null(store.Get(firstOtherDay));
        Assert.Equal(state, store.Get(sibling));
        Assert.Equal(state, store.Get(catalog));
        Assert.Equal("novena", DesktopPrayerIdentity.DevotionID("novena", null));
    }
}
