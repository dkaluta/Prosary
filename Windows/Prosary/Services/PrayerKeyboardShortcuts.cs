using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Documents;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Models;
using Prosary.ViewModels;
using Windows.System;
using CoreVirtualKeyStates = Windows.UI.Core.CoreVirtualKeyStates;

namespace Prosary.Services;

/// <summary>Each native window owns its shortcuts; no global listener can advance a sibling
/// prayer. Preview handling reaches the reader before its ScrollViewer consumes the key.</summary>
internal static class PrayerKeyboardShortcuts
{
    public static void Attach(Window owner, FrameworkElement root, Frame frame)
    {
        var isActive = false;
        void Activated(object sender, WindowActivatedEventArgs args) =>
            isActive = args.WindowActivationState != WindowActivationState.Deactivated;

        void KeyDown(object sender, KeyRoutedEventArgs args)
        {
            var key = args.Key switch
            {
                VirtualKey.Left => PrayerNavigationKey.Left,
                VirtualKey.Right => PrayerNavigationKey.Right,
                VirtualKey.Space => PrayerNavigationKey.Space,
                _ => PrayerNavigationKey.Other,
            };
            if (args.Handled || key == PrayerNavigationKey.Other || root.XamlRoot is null
                || frame.Content is not Page { IsLoaded: true }
                || DesktopWindowChrome.CurrentFlow(frame) is not { } flow
                || string.IsNullOrEmpty(flow.ProgressText)) return;

            // A series choice can be an inline InfoBar, rather than a modal ContentDialog.
            var hasPrompt = flow switch
            {
                CustomDevotionViewModel custom => custom.HasSavedContinuation
                    || custom.ShowsMissedDayChoice || custom.ShowsCompletionSuggestion,
                RosaryViewModel rosary => rosary.HasSavedContinuation,
                JesusPrayerViewModel jesus => jesus.HasSavedContinuation,
                _ => false,
            };
            hasPrompt |= VisualTreeHelper.GetOpenPopupsForXamlRoot(root.XamlRoot).Any(popup => popup.IsOpen);
            var focus = FocusManager.GetFocusedElement(root.XamlRoot) as DependencyObject;
            var action = PrayerKeyboardNavigation.Resolve(key, AppSettings.KeyboardArrowNavigationEnabled,
                AppSettings.KeyboardSpaceAdvanceEnabled, UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current),
                isActiveWindow: isActive, hasModifiers: HasModifiers(), isRepeat: args.KeyStatus.WasKeyDown,
                focusConsumesKey: FocusConsumesKey(focus, key), hasPrompt: hasPrompt);
            if (action == PrayerKeyboardAction.None) return;

            // Consume a recognized shortcut at the boundary too: Left on the first step must
            // not unexpectedly scroll or change a focused control after choosing navigation.
            args.Handled = true;
            if (action == PrayerKeyboardAction.Previous && !flow.CanGoBack) return;
            var command = action == PrayerKeyboardAction.Next ? flow.NextCommand : flow.BackCommand;
            if (command.CanExecute(null)) command.Execute(null);
        }

        owner.Activated += Activated;
        root.PreviewKeyDown += KeyDown;
        owner.Closed += (_, _) =>
        {
            owner.Activated -= Activated;
            root.PreviewKeyDown -= KeyDown;
        };
    }

    private static bool HasModifiers() => IsDown(VirtualKey.Control) || IsDown(VirtualKey.Menu)
        || IsDown(VirtualKey.Shift) || IsDown(VirtualKey.LeftWindows) || IsDown(VirtualKey.RightWindows);

    private static bool IsDown(VirtualKey key) =>
        (InputKeyboardSource.GetKeyStateForCurrentThread(key) & CoreVirtualKeyStates.Down) != 0;

    private static bool FocusConsumesKey(DependencyObject? focused, PrayerNavigationKey key)
    {
        for (var element = focused; element is not null; element = VisualTreeHelper.GetParent(element))
        {
            if (element is TextBox or RichEditBox or PasswordBox or AutoSuggestBox or NumberBox
                or Selector or RangeBase or ToggleSwitch or DatePicker or TimePicker
                or CalendarDatePicker or CalendarView or MenuBar or MenuBarItem or MenuFlyoutPresenter
                or ContentDialog or Hyperlink) return true;
            if (key == PrayerNavigationKey.Space && element is ButtonBase) return true;
            if (element is TextBlock { SelectedText.Length: > 0 }
                or RichTextBlock { SelectedText.Length: > 0 }) return true;
        }
        return false;
    }
}
