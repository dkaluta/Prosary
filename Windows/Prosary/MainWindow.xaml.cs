using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Prosary.Navigation;
using Prosary.Views;
using Windows.UI;
using WinRT.Interop;

namespace Prosary;

public sealed partial class MainWindow : Window
{
    [DllImport("user32.dll")]
    private static extern int GetDpiForWindow(IntPtr hwnd);

    public MainWindow()
    {
        InitializeComponent();
        Title = "Prosary";

        // Hebrew (or any RTL app language) flips the whole tree — resources themselves resolve
        // per the app language, this only handles layout direction (v0.7, Gamaliel item 3).
        var appLanguage = Windows.Globalization.ApplicationLanguages.Languages.FirstOrDefault() ?? "en";
        if (appLanguage.StartsWith("he", StringComparison.OrdinalIgnoreCase)
            || appLanguage.StartsWith("ar", StringComparison.OrdinalIgnoreCase))
        {
            if (Content is FrameworkElement rootElement)
            {
                rootElement.FlowDirection = FlowDirection.RightToLeft;
            }
        }

        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        if (appWindow?.Presenter is OverlappedPresenter presenter)
        {
            // Windows keeps a 760pt floor so its NavigationView pane plus the prayer surface do
            // not squeeze the wide layout. The Mac app now permits a 620pt window and switches
            // its content to a narrow layout below 700pt; WinUI's persistent sidebar needs the
            // larger floor here. Height keeps irosary's original 600pt minimum.
            //
            // PreferredMinimumWidth/Height take raw physical pixels, not the DPI-independent
            // effective pixels these numbers are expressed in — left un-scaled, the window would
            // enforce a floor that's the intended physical size only at 100% display scaling, and
            // shrinks on any HiDPI screen (125%/150%/200%, common on modern laptops) to a fraction
            // of the real screen space this app's narrow-layout breakpoint actually needs. Scaling
            // by the window's own current DPI keeps the enforced minimum the same physical size
            // everywhere — unchanged at 100%, proportionally larger in raw pixels above it.
            var scale = GetDpiForWindow(hwnd) / 96.0;
            presenter.PreferredMinimumWidth = (int)(760 * scale);
            presenter.PreferredMinimumHeight = (int)(600 * scale);
        }

        // Fluent-style extended title bar: AppTitleBar (see MainWindow.xaml) draws behind the
        // system caption buttons instead of the default opaque OS title bar strip, matching
        // contemporary Windows 11 app chrome (Settings, Mail, etc.) rather than the classic
        // Win32-style title bar every page in this app would otherwise sit below.
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        // BaseAlt (not the plain Base Mica used by windows with a normal title bar) is
        // Microsoft's documented recommendation specifically for extended-title-bar windows —
        // NOT verified on-screen from this (non-Windows) environment; if the title bar area reads
        // as too dark/too light against AppTitleBar's content on a real build, this is the first
        // thing to try swapping (Mica.Base, or a plain SolidColorBrush) instead.
        SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };

        if (appWindow is not null)
        {
            var titleBar = appWindow.TitleBar;
            titleBar.ButtonBackgroundColor = Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;

            // Keeps AppTitleBar's own content (icon/title) from ever sitting underneath the
            // system caption buttons, which the OS draws in the top-right (top-left in RTL)
            // corner on top of whatever this window's content is at that position.
            RightPaddingColumn.Width = new GridLength(titleBar.RightInset);
        }

        Router.Initialize(RootFrame);
        // Selecting the item routes through OnNavSelectionChanged, which navigates to Home.
        AppNav.SelectedItem = AppNav.MenuItems[0];
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;
        // Sections behave like tabs: switching resets the stack instead of pushing onto it.
        switch (item.Tag as string)
        {
            case "pray": Router.Navigate<HomePage>(); break;
            case "browse": Router.Navigate<RepositoryBrowserPage>(); break;
            case "categories": Router.Navigate<CategoriesPage>(); break;
            case "search": Router.Navigate<SearchPage>(); break;
            default: return;
        }
        // Frame.Navigate adds the page we just left to BackStack, so clear only after the new
        // section root is active. Clearing first left that old page as one phantom Back step.
        RootFrame.BackStack.Clear();
    }
}
