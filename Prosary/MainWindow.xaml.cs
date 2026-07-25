using Microsoft.UI;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Prosary.Navigation;
using Prosary.Views;
using Windows.UI;
using WinRT.Interop;

namespace Prosary;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Title = "Prosary";

        var hwnd = WindowNative.GetWindowHandle(this);
        var windowId = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(windowId);
        if (appWindow?.Presenter is OverlappedPresenter presenter)
        {
            // Matches irosary's MinimumWidth=420/MinimumHeight=600 floor (App.xaml.cs
            // CreateWindow override there), plus a width ceiling matching iOS's own Mac
            // WindowGroup (.frame(minWidth: 760, idealWidth: 1000, maxWidth: 1400, ...)) — without
            // one, the wide Rosary/Angelus/Jesus Prayer layout's body text stretches across the
            // full width of an ultra-wide/maximized window instead of staying a comfortable
            // reading line length. No height ceiling, matching iOS not capping height either.
            presenter.PreferredMinimumWidth = 420;
            presenter.PreferredMinimumHeight = 600;
            presenter.PreferredMaximumWidth = 1400;
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
        Router.Navigate<HomePage>();
    }
}
