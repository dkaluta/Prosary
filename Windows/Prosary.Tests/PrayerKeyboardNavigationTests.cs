using Prosary.Models;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerKeyboardNavigationTests
{
    [Theory]
    [InlineData(false, PrayerNavigationKey.Left, PrayerKeyboardAction.Previous)]
    [InlineData(false, PrayerNavigationKey.Right, PrayerKeyboardAction.Next)]
    [InlineData(true, PrayerNavigationKey.Left, PrayerKeyboardAction.Next)]
    [InlineData(true, PrayerNavigationKey.Right, PrayerKeyboardAction.Previous)]
    [InlineData(false, PrayerNavigationKey.Space, PrayerKeyboardAction.Next)]
    [InlineData(true, PrayerNavigationKey.Space, PrayerKeyboardAction.Next)]
    public void ReadingDirectionChangesArrowsButNeverTheSpaceAction(bool rtl,
        PrayerNavigationKey key, PrayerKeyboardAction expected) =>
        Assert.Equal(expected, PrayerKeyboardNavigation.Resolve(key, true, true, rtl));

    [Fact]
    public void ArrowAndSpacePreferencesAreIndependent()
    {
        Assert.Equal(PrayerKeyboardAction.Next,
            PrayerKeyboardNavigation.Resolve(PrayerNavigationKey.Right, true, false, false));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(PrayerNavigationKey.Space, true, false, false));
        Assert.Equal(PrayerKeyboardAction.Next,
            PrayerKeyboardNavigation.Resolve(PrayerNavigationKey.Space, false, true, false));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(PrayerNavigationKey.Right, false, true, false));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(PrayerNavigationKey.Other, true, true, false));
    }

    [Theory]
    [InlineData(PrayerNavigationKey.Left)]
    [InlineData(PrayerNavigationKey.Right)]
    [InlineData(PrayerNavigationKey.Space)]
    public void AnInactiveWindowOrPromptNeverChangesPrayerProgress(PrayerNavigationKey key)
    {
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(key, true, true, false, isActiveWindow: false));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(key, true, true, false, hasPrompt: true));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(key, true, true, false, focusConsumesKey: true));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(key, true, true, false, hasModifiers: true));
        Assert.Equal(PrayerKeyboardAction.None,
            PrayerKeyboardNavigation.Resolve(key, true, true, false, isRepeat: true));
    }

    [Fact]
    public void SettingsPersistEachChoiceWithoutChangingTheOther()
    {
        var arrows = AppSettings.KeyboardArrowNavigationEnabled;
        var space = AppSettings.KeyboardSpaceAdvanceEnabled;
        try
        {
            AppSettings.SetKeyboardArrowNavigationEnabled(true);
            AppSettings.SetKeyboardSpaceAdvanceEnabled(true);
            var settings = new SettingsViewModel(initialAudioCacheBytes: 0);
            settings.KeyboardArrowNavigationEnabled = false;
            Assert.False(AppSettings.KeyboardArrowNavigationEnabled);
            Assert.True(AppSettings.KeyboardSpaceAdvanceEnabled);
            settings.KeyboardSpaceAdvanceEnabled = false;
            settings.KeyboardArrowNavigationEnabled = true;
            var reloaded = new SettingsViewModel(initialAudioCacheBytes: 0);
            Assert.True(reloaded.KeyboardArrowNavigationEnabled);
            Assert.False(reloaded.KeyboardSpaceAdvanceEnabled);
        }
        finally
        {
            AppSettings.SetKeyboardArrowNavigationEnabled(arrows);
            AppSettings.SetKeyboardSpaceAdvanceEnabled(space);
        }
    }
}
