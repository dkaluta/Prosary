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

        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        if (appWindow?.Presenter is OverlappedPresenter presenter)
        {
            // Minimum width matches iOS's own Mac WindowGroup exactly (.frame(minWidth: 760, ...)
            // in ProsaryApp.swift) rather than irosary's narrower MinimumWidth=420 — 760 is tuned
            // for the wide 3-column Rosary flow layout specifically, per that file's own comment
            // ("the window itself needs a floor to keep the wide 3-column Rosary flow layout from
            // being resized into something cramped and broken"), the same layout this Windows
            // port has too. Height keeps irosary's original 600 floor; only width was asked to
            // match Mac's.
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
        RootFrame.BackStack.Clear();
        switch (item.Tag as string)
        {
            case "pray": Router.Navigate<HomePage>(); break;
            case "browse": Router.Navigate<RepositoryBrowserPage>(); break;
            case "categories": Router.Navigate<CategoriesPage>(); break;
            case "search": Router.Navigate<SearchPage>(); break;
        }
    }
}
