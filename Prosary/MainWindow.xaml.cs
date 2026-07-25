using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Prosary.Navigation;
using Prosary.Views;
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
            // Matches irosary's MinimumWidth=420/MinimumHeight=600 choice (App.xaml.cs
            // CreateWindow override there) — no maximum, to support the Rosary flow's
            // responsive narrow/wide layout at any window size above this floor.
            presenter.PreferredMinimumWidth = 420;
            presenter.PreferredMinimumHeight = 600;
        }

        Router.Initialize(RootFrame);
        Router.Navigate<HomePage>();
    }
}
