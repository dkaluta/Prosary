using System.Runtime.InteropServices;
using System.ComponentModel;
using Microsoft.UI;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.ViewModels;
using Prosary.Views;
using Windows.System;
using WinRT.Interop;

namespace Prosary.Services;

/// <summary>Windows commands live in each window's MenuBar and retain that window as owner.</summary>
internal static class DesktopWindowChrome
{
    [DllImport("user32.dll")]
    private static extern int GetDpiForWindow(IntPtr hwnd);

    public static void Configure(Window window, FrameworkElement root, UIElement titleBar,
        ColumnDefinition leftInset, ColumnDefinition rightInset, int minimumWidth)
    {
        root.FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        var hwnd = WindowNative.GetWindowHandle(window);
        var appWindow = AppWindow.GetFromWindowId(Win32Interop.GetWindowIdFromWindow(hwnd));
        if (appWindow.Presenter is OverlappedPresenter presenter)
        {
            var scale = GetDpiForWindow(hwnd) / 96.0;
            presenter.PreferredMinimumWidth = (int)(minimumWidth * scale);
            presenter.PreferredMinimumHeight = (int)(600 * scale);
        }
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);
        window.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };
        appWindow.TitleBar.ButtonBackgroundColor = Colors.Transparent;
        appWindow.TitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        // Caption insets use physical pixels; the XAML grid uses effective pixels.
        if (titleBar is FrameworkElement titleElement)
        {
            titleElement.FlowDirection = FlowDirection.LeftToRight;
            if (titleElement is Panel panel)
                foreach (var text in panel.Children.OfType<TextBlock>()) text.FlowDirection = root.FlowDirection;
        }
        void RefreshInsets()
        {
            var scale = root.XamlRoot?.RasterizationScale ?? GetDpiForWindow(hwnd) / 96.0;
            leftInset.Width = new GridLength(appWindow.TitleBar.LeftInset / scale);
            rightInset.Width = new GridLength(appWindow.TitleBar.RightInset / scale);
            if (appWindow.Presenter is OverlappedPresenter currentPresenter)
            {
                currentPresenter.PreferredMinimumWidth = (int)(minimumWidth * scale);
                currentPresenter.PreferredMinimumHeight = (int)(600 * scale);
            }
        }
        void RootChanged(XamlRoot sender, XamlRootChangedEventArgs args) => RefreshInsets();
        XamlRoot? observedRoot = null;
        root.Loaded += (_, _) =>
        {
            if (observedRoot is not null) observedRoot.Changed -= RootChanged;
            observedRoot = root.XamlRoot;
            if (observedRoot is not null) observedRoot.Changed += RootChanged;
            RefreshInsets();
        };
        root.SizeChanged += (_, _) => RefreshInsets();
        window.Closed += (_, _) =>
        {
            if (observedRoot is not null) observedRoot.Changed -= RootChanged;
        };
        RefreshInsets();
    }

    public static void Populate(MenuBar menu, Window owner, Frame frame, Func<Guid?>? savedID = null)
    {
        var navigation = Router.For(frame);
        var file = new MenuBarItem { Title = Loc.Tr("desktop_menu_file", "File") };
        file.Items.Add(Item("desktop_import", "Import Prayer Packs…", async () => await ImportAsync(owner, navigation), VirtualKey.O));
        file.Items.Add(new MenuFlyoutSeparator());
        file.Items.Add(Item("desktop_close_window", "Close Window", owner.Close, VirtualKey.W));
        menu.Items.Add(file);

        var view = new MenuBarItem { Title = Loc.Tr("desktop_menu_view", "View") };
        view.Items.Add(Item("desktop_show_library", "Show Library", () => DesktopWindowManager.ShowLibrary(), VirtualKey.L));
        view.Items.Add(Item("desktop_today", "Today", () => DesktopWindowManager.ShowLibrary("today")));
        view.Items.Add(Item("desktop_gallery", "Gallery", () => DesktopWindowManager.ShowLibrary("gallery")));
        view.Items.Add(Item("BasicPrayersTitle/Text", "Basic Prayers", () => DesktopWindowManager.ShowLibrary("basic")));
        view.Items.Add(Item("SearchTitle/Text", "Search", () => DesktopWindowManager.ShowLibrary("search"), VirtualKey.F));
        view.Items.Add(Item("desktop_community", "Community", () => DesktopWindowManager.ShowLibrary("community")));
        view.Items.Add(new MenuFlyoutSeparator());
        view.Items.Add(Item("desktop_full_screen", "Full Screen", () =>
        {
            var appWindow = AppWindow.GetFromWindowId(Win32Interop.GetWindowIdFromWindow(WindowNative.GetWindowHandle(owner)));
            appWindow.SetPresenter(appWindow.Presenter.Kind == AppWindowPresenterKind.FullScreen
                ? AppWindowPresenterKind.Overlapped : AppWindowPresenterKind.FullScreen);
        }, VirtualKey.F11, VirtualKeyModifiers.None));
        menu.Items.Add(view);

        var prayer = new MenuBarItem { Title = Loc.Tr("desktop_menu_prayer", "Prayer") };
        var previous = Item("desktop_previous_step", "Previous Step", () => ExecuteStep(frame, false), VirtualKey.Left);
        var next = Item("desktop_next_step", "Next Step", () => ExecuteStep(frame, true), VirtualKey.Right);
        prayer.Items.Add(previous);
        prayer.Items.Add(next);
        var settings = Item("desktop_prayer_settings", "Prayer Settings…", () =>
        {
            if (savedID?.Invoke() is not { } id) return;
            if (frame.Content is RosaryPrayerPage or JesusPrayerFlowPage) navigation.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(id));
            else navigation.Navigate<RemindersOnlyEditorPage>(id);
        });
        prayer.Items.Add(new MenuFlyoutSeparator());
        prayer.Items.Add(settings);
        void RefreshCommands()
        {
            var flow = CurrentFlow(frame);
            previous.IsEnabled = flow?.BackCommand.CanExecute(null) == true && flow.CanGoBack;
            next.IsEnabled = flow?.NextCommand.CanExecute(null) == true;
            settings.IsEnabled = savedID?.Invoke() is not null && flow is not null;
        }
        // CanExecute is evaluated again when invoked; menu availability follows the current page.
        prayer.PointerEntered += (_, _) => RefreshCommands();
        prayer.GotFocus += (_, _) => RefreshCommands();
        INotifyPropertyChanged? observedFlow = null;
        void FlowChanged(object? sender, PropertyChangedEventArgs args) => RefreshCommands();
        frame.Navigated += (_, _) =>
        {
            if (observedFlow is not null) observedFlow.PropertyChanged -= FlowChanged;
            observedFlow = CurrentFlow(frame) as INotifyPropertyChanged;
            if (observedFlow is not null) observedFlow.PropertyChanged += FlowChanged;
            RefreshCommands();
        };
        owner.Closed += (_, _) =>
        {
            if (observedFlow is not null) observedFlow.PropertyChanged -= FlowChanged;
        };
        RefreshCommands();
        menu.Items.Add(prayer);

        var help = new MenuBarItem { Title = Loc.Tr("desktop_menu_help", "Help") };
        help.Items.Add(Item("SetTitle/Text", "Settings", () => DesktopWindowManager.ShowLibrary("settings")));
        help.Items.Add(Item("AbtTitle/Text", "About", () => DesktopWindowManager.ShowLibrary("about")));
        menu.Items.Add(help);
    }

    private static IPrayerStepFlowViewModel? CurrentFlow(Frame frame) => frame.Content switch
    {
        RosaryPrayerPage page => page.ViewModel,
        CustomDevotionFlowPage page => page.ViewModel,
        JesusPrayerFlowPage page => page.ViewModel,
        BasicPrayerFlowPage page => page.ViewModel,
        _ => null,
    };

    private static void ExecuteStep(Frame frame, bool next)
    {
        var flow = CurrentFlow(frame);
        if (flow is null || (!next && !flow.CanGoBack)) return;
        var command = next ? flow.NextCommand : flow.BackCommand;
        if (command.CanExecute(null)) command.Execute(null);
    }

    private static MenuFlyoutItem Item(string key, string fallback, Action action,
        VirtualKey? keyCode = null, VirtualKeyModifiers modifiers = VirtualKeyModifiers.Control)
    {
        var item = new MenuFlyoutItem { Text = Loc.Tr(key, fallback) };
        item.Click += (_, _) => action();
        if (keyCode is { } keyValue)
            item.KeyboardAccelerators.Add(new KeyboardAccelerator { Key = keyValue, Modifiers = modifiers });
        return item;
    }

    private static async Task ImportAsync(Window owner, WindowNavigation navigation)
    {
        try
        {
            var picker = new Windows.Storage.Pickers.FileOpenPicker();
            InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(owner));
            picker.FileTypeFilter.Add(".prosaryprayer");
            var files = await picker.PickMultipleFilesAsync();
            if (navigation.OwnerWindow is null || files.Count == 0) return;
            foreach (var file in files)
            {
                using var stream = await file.OpenStreamForReadAsync();
                var bytes = await PrayerPackStore.ReadInstallBytesAsync(stream);
                if (navigation.OwnerWindow is null) return;
                PrayerPackStore.InstallPack(bytes);
            }
            if (navigation.OwnerWindow is null) return;
            Persistence.DesktopLibraryChanges.Publish();
            DesktopWindowManager.ShowLibrary("gallery");
        }
        catch (Exception error)
        {
            if (navigation.OwnerWindow is null) return;
            if (owner.Content is not FrameworkElement { XamlRoot: { } root }) return;
            var dialog = new ContentDialog
            {
                XamlRoot = root,
                Title = Loc.Tr("desktop_import_failed", "Could Not Import Prayer Pack"),
                Content = error.Message,
                CloseButtonText = Loc.Tr("common_ok", "OK"),
            };
            try { await dialog.ShowAsync(); }
            catch (Exception dialogError) { System.Diagnostics.Debug.WriteLine(dialogError); }
        }
    }
}
