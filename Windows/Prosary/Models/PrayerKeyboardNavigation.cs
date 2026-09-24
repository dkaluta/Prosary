namespace Prosary.Models;

public enum PrayerNavigationKey { Other, Left, Right, Space }
public enum PrayerKeyboardAction { None, Previous, Next }

/// <summary>The unmodified prayer shortcuts follow interface direction, independently of
/// prayer language. All window, focus and prompt checks must pass before choosing an action.</summary>
public static class PrayerKeyboardNavigation
{
    public static PrayerKeyboardAction Resolve(PrayerNavigationKey key, bool arrowsEnabled,
        bool spaceEnabled, bool isRightToLeft, bool isActiveWindow = true,
        bool hasModifiers = false, bool isRepeat = false, bool focusConsumesKey = false,
        bool hasPrompt = false)
    {
        if (!isActiveWindow || hasModifiers || isRepeat || focusConsumesKey || hasPrompt)
            return PrayerKeyboardAction.None;
        return key switch
        {
            PrayerNavigationKey.Space when spaceEnabled => PrayerKeyboardAction.Next,
            PrayerNavigationKey.Left when arrowsEnabled => isRightToLeft
                ? PrayerKeyboardAction.Next : PrayerKeyboardAction.Previous,
            PrayerNavigationKey.Right when arrowsEnabled => isRightToLeft
                ? PrayerKeyboardAction.Previous : PrayerKeyboardAction.Next,
            _ => PrayerKeyboardAction.None,
        };
    }
}
