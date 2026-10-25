using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.Services;
using Prosary.Views;

namespace Prosary;

/// <summary>The library is one native window; opening a prayer preserves its selection and sidebar.</summary>
public sealed partial class MainWindow : Window
{
    private readonly Dictionary<string, ReferenceWindow> _referenceWindows = new();
    private ContentDialog? _readingsDialog;
    private bool _showingReadings;
    private bool _isClosed;
    public MainWindow()
    {
        InitializeComponent();
        Title = "Prosary";
        DesktopWindowChrome.Configure(this, WindowRoot, AppTitleBar, LeftPaddingColumn, RightPaddingColumn, 760);
        Router.Register(RootFrame, this);
        DesktopWindowChrome.Populate(WindowMenus, this, RootFrame);
        AppNav.MenuItems.Add(Section("home", "home_widgets_title", "Home", "\uE80F"));
        AppNav.MenuItems.Add(Section("library", "desktop_library", "Library", "\uE8F1"));
        AppNav.MenuItems.Add(Section("today", "desktop_today", "Today", "\uE787"));
        AppNav.MenuItems.Add(Section("bible", "bible_title", "Bible", "\uE8A9"));
        AppNav.MenuItems.Add(Section("gallery", "desktop_gallery", "Gallery", "\uE8B9"));
        AppNav.MenuItems.Add(Section("basic", "BasicPrayersTitle/Text", "Basic Prayers", "\uE8A5"));
        AppNav.MenuItems.Add(Section("search", "SearchTitle/Text", "Search", "\uE721"));
        AppNav.FooterMenuItems.Add(Section("settings", "SetTitle/Text", "Settings", "\uE713"));
        AppNav.FooterMenuItems.Add(Section("about", "AbtTitle/Text", "About", "\uE946"));
        Closed += (_, _) =>
        {
            _isClosed = true;
            _readingsDialog?.Hide();
            foreach (var reference in _referenceWindows.Values.ToArray()) reference.Close();
            Router.Unregister(RootFrame);
            RootFrame.Content = null;
        };
    }

    private static NavigationViewItem Section(string tag, string key, string fallback, string glyph) => new()
    {
        Tag = tag, Content = Loc.Tr(key, fallback), Icon = new FontIcon { Glyph = glyph },
    };

    public void SelectSection(string section)
    {
        // Keep the reminder/deep-link destination while readings is a modal reference.
        if (section == "readings") { ShowReadingsMode("daily"); return; }
        // Community discovery belongs to Search; retain this internal route for old callers.
        if (section == "community")
        {
            SelectSection("search");
            Router.For(RootFrame).Navigate<RepositoryBrowserPage>();
            return;
        }
        var item = AppNav.MenuItems.Concat(AppNav.FooterMenuItems)
            .OfType<NavigationViewItem>().FirstOrDefault(item => item.Tag as string == section)
            ?? AppNav.MenuItems.OfType<NavigationViewItem>().First();
        if (ReferenceEquals(AppNav.SelectedItem, item)) { NavigateSection(item); return; }
        AppNav.SelectedItem = item;
    }

    public void ShowTodayReadings(bool readingsOnly)
    {
        var navigation = Router.For(RootFrame);
        navigation.Today?.SelectTodayCommand.Execute(null);
        if (readingsOnly)
        {
            ShowReadingsMode("daily");
        }
        else SelectSection("today");
    }

    public async void ShowReadingsMode(string mode)
    {
        if (mode == "bible") { SelectSection("bible"); return; }
        if (mode == "calendar")
        {
            if (_referenceWindows.TryGetValue(mode, out var existing)) { existing.Activate(); return; }
            var reference = new ReferenceWindow(Router.For(RootFrame).Today, date =>
            {
                if (Router.For(RootFrame).Today is { } today)
                    today.SelectedTodayDate = new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue));
                Activate();
                ShowReadingsMode("daily");
            });
            _referenceWindows.Add(mode, reference);
            reference.Closed += (_, _) => _referenceWindows.Remove(mode);
            reference.Activate();
            return;
        }
        await ShowDailyReadingsAsync();
    }

    private async Task ShowDailyReadingsAsync()
    {
        if (_showingReadings) return;
        _showingReadings = true;
        try
        {
            // Protocol activation can arrive before the library has connected its XamlRoot.
            if (RootFrame.Content is not Page page || !await Router.WaitUntilLoadedAsync(page)) return;
            if (Router.For(RootFrame).Today is not { } today || WindowRoot.XamlRoot is not { } root) return;
            if (!await WaitForContentDialogsAsync(root) || _isClosed) return;
            var content = new ContentControl
            {
                Content = new DesktopTodayPage(today, readingsOnly: true),
                HorizontalContentAlignment = HorizontalAlignment.Stretch,
                VerticalContentAlignment = VerticalAlignment.Stretch,
            };
            var dialog = new ContentDialog
            {
                XamlRoot = root,
                Title = Loc.Tr("bible_daily_readings", "Daily Readings"),
                Content = content,
                CloseButtonText = Loc.Tr("common_close", "Close"),
                DefaultButton = ContentDialogButton.Close,
                FlowDirection = WindowRoot.FlowDirection,
            };
            dialog.Resources["ContentDialogMaxWidth"] = 960d;
            void Resize()
            {
                // The page owns scrolling; reserve native title/button space outside it.
                content.Width = Math.Max(0, Math.Min(900, root.Size.Width - 96));
                content.Height = Math.Max(0, Math.Min(720, root.Size.Height - 200));
                dialog.MaxHeight = Math.Max(0, root.Size.Height - 32);
            }
            void OnRootChanged(XamlRoot sender, XamlRootChangedEventArgs args) => Resize();
            Resize();
            root.Changed += OnRootChanged;
            _readingsDialog = dialog;
            try { await dialog.ShowAsync(); }
            finally
            {
                root.Changed -= OnRootChanged;
                content.Content = null;
                _readingsDialog = null;
            }
        }
        catch (OperationCanceledException) when (_isClosed) { }
        catch (System.Runtime.InteropServices.COMException) when (_isClosed) { }
        finally { _showingReadings = false; }
    }

    private async Task<bool> WaitForContentDialogsAsync(XamlRoot root)
    {
        // A reminder may arrive while Home customization or another native modal is open.
        // Keep that editor intact and present readings when it dismisses.
        while (VisualTreeHelper.GetOpenPopupsForXamlRoot(root)
            .Select(popup => FindContentDialog(popup.Child)).FirstOrDefault(dialog => dialog is not null) is { } active)
        {
            var completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            void DialogClosed(ContentDialog sender, ContentDialogClosedEventArgs args) => completion.TrySetResult(true);
            void OwnerClosed(object sender, WindowEventArgs args) => completion.TrySetResult(false);
            active.Closed += DialogClosed;
            Closed += OwnerClosed;
            try { if (!await completion.Task) return false; }
            finally { active.Closed -= DialogClosed; Closed -= OwnerClosed; }
        }
        return !_isClosed;
    }

    private static ContentDialog? FindContentDialog(DependencyObject? element)
    {
        if (element is ContentDialog dialog) return dialog;
        if (element is null) return null;
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(element); index++)
            if (FindContentDialog(VisualTreeHelper.GetChild(element, index)) is { } child) return child;
        return null;
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;
        NavigateSection(item);
    }

    private void NavigateSection(NavigationViewItem item)
    {
        var navigation = Router.For(RootFrame);
        switch (item.Tag as string)
        {
            case "home": navigation.Navigate<DashboardPage>(); break;
            case "library": navigation.Navigate<DesktopLibraryPage>(); break;
            case "today": navigation.Navigate<DesktopTodayPage>(); break;
            case "bible": navigation.Navigate<DesktopBiblePage>(); break;
            case "gallery": navigation.Navigate<DesktopGalleryPage>(); break;
            case "basic": navigation.Navigate<BasicPrayersPage>(); break;
            case "search":
                navigation.Navigate<SearchPage>();
                if (RootFrame.Content is SearchPage search) search.FocusSearch();
                break;
            case "settings": navigation.Navigate<SettingsPage>(); break;
            case "about": navigation.Navigate<AboutPage>(); break;
            default: return;
        }
        RootFrame.BackStack.Clear();
    }
}
