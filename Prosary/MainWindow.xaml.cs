using System.Runtime.InteropServices;
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
            // PreferredMinimumWidth/Height take raw physical pixels, not the DPI-independent
            // effective pixels the rest of XAML sizing (and irosary's own MinimumWidth=420/
            // MinimumHeight=600, this floor's source) uses — left as literal 420/600, the window
            // would enforce a floor that's the intended physical size only at 100% scaling, and
            // shrinks on any HiDPI display (125%/150%/200%, common on modern laptops) to a
            // fraction of the real screen space this app's narrow-layout breakpoint actually
            // needs. Scaling by the window's own current DPI keeps the enforced minimum the same
            // physical size everywhere — unchanged at 100%, larger in raw pixels at higher scales.
            var scale = GetDpiForWindow(hwnd) / 96.0;
            presenter.PreferredMinimumWidth = (int)(420 * scale);
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
        Router.Navigate<HomePage>();
    }
}
