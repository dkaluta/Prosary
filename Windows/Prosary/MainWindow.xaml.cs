using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.Services;
using Prosary.Views;

namespace Prosary;

/// <summary>The library is one native window; opening a prayer preserves its selection and sidebar.</summary>
public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "Prosary";
        DesktopWindowChrome.Configure(this, WindowRoot, AppTitleBar, LeftPaddingColumn, RightPaddingColumn, 760);
        Router.Register(RootFrame, this);
        DesktopWindowChrome.Populate(WindowMenus, this, RootFrame);
        AppNav.MenuItems.Add(Section("library", "desktop_library", "Library", "\uE8F1"));
        AppNav.MenuItems.Add(Section("today", "desktop_today", "Today", "\uE787"));
        AppNav.MenuItems.Add(Section("gallery", "desktop_gallery", "Gallery", "\uE8B9"));
        AppNav.MenuItems.Add(Section("basic", "BasicPrayersTitle/Text", "Basic Prayers", "\uE8A5"));
        AppNav.MenuItems.Add(Section("search", "SearchTitle/Text", "Search", "\uE721"));
        AppNav.MenuItems.Add(Section("community", "desktop_community", "Community", "\uE902"));
        AppNav.FooterMenuItems.Add(Section("settings", "SetTitle/Text", "Settings", "\uE713"));
        AppNav.FooterMenuItems.Add(Section("about", "AbtTitle/Text", "About", "\uE946"));
        Closed += (_, _) =>
        {
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
        var item = AppNav.MenuItems.Concat(AppNav.FooterMenuItems)
            .OfType<NavigationViewItem>().FirstOrDefault(item => item.Tag as string == section)
            ?? AppNav.MenuItems.OfType<NavigationViewItem>().First();
        if (ReferenceEquals(AppNav.SelectedItem, item)) { NavigateSection(item); return; }
        AppNav.SelectedItem = item;
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
            case "library": navigation.Navigate<DesktopLibraryPage>(); break;
            case "today": navigation.Navigate<DesktopTodayPage>(); break;
            case "gallery": navigation.Navigate<DesktopGalleryPage>(); break;
            case "basic": navigation.Navigate<BasicPrayersPage>(); break;
            case "search":
                navigation.Navigate<SearchPage>();
                if (RootFrame.Content is SearchPage search) search.FocusSearch();
                break;
            case "community": navigation.Navigate<RepositoryBrowserPage>(); break;
            case "settings": navigation.Navigate<SettingsPage>(); break;
            case "about": navigation.Navigate<AboutPage>(); break;
            default: return;
        }
        RootFrame.BackStack.Clear();
    }
}
