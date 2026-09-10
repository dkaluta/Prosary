using System.Runtime.CompilerServices;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Services;

namespace Prosary.Navigation;

/// <summary>Navigation belongs to the originating page's window, including after an await.</summary>
public static class Router
{
    private static readonly ConditionalWeakTable<Frame, WindowNavigationContext> Contexts = new();

    public static void Register(Frame frame, Window window, bool isPrayerWindow = false)
    {
        Unregister(frame);
        Contexts.Add(frame, new WindowNavigationContext(frame, window, isPrayerWindow));
    }

    public static void Unregister(Frame frame)
    {
        if (Contexts.TryGetValue(frame, out var context)) context.Dispose();
        Contexts.Remove(frame);
    }

    public static WindowNavigation For(Page page) => new(() =>
        page.Frame is { } frame && ReferenceEquals(frame.Content, page) ? frame : null);
    public static WindowNavigation For(Frame frame) => new(() => frame);
    public static Window WindowFor(Page page) => For(page).OwnerWindow
        ?? throw new InvalidOperationException("The page is not attached to a window.");
    /// <summary>Frame navigation may start before the native window has connected its XamlRoot.</summary>
    public static async Task<bool> WaitUntilLoadedAsync(Page page)
    {
        var context = ContextFor(page.Frame);
        if (context is not { IsClosed: false }) return false;
        var owner = context.Window;
        if (page.IsLoaded && page.XamlRoot is not null) return For(page).OwnerWindow == owner;
        var completion = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        void Loaded(object sender, RoutedEventArgs args) => completion.TrySetResult(page.XamlRoot is not null);
        void Unloaded(object sender, RoutedEventArgs args) => completion.TrySetResult(false);
        void Closed(object sender, WindowEventArgs args) => completion.TrySetResult(false);
        void Navigating(object sender, NavigatingCancelEventArgs args) => completion.TrySetResult(false);
        page.Loaded += Loaded;
        page.Unloaded += Unloaded;
        owner.Closed += Closed;
        context.Frame.Navigating += Navigating;
        try { return await completion.Task && For(page).OwnerWindow == owner; }
        finally
        {
            page.Loaded -= Loaded;
            page.Unloaded -= Unloaded;
            owner.Closed -= Closed;
            context.Frame.Navigating -= Navigating;
        }
    }

    internal static WindowNavigationContext? ContextFor(Frame? frame) =>
        frame is not null && Contexts.TryGetValue(frame, out var context) ? context : null;

    internal static bool IsDuplicateNavigation(Type? currentPageType, object? currentParameter,
        Type destinationPageType, object? destinationParameter) =>
        currentPageType == destinationPageType && Equals(currentParameter, destinationParameter);
}

public sealed class WindowNavigation(Func<Frame?> frame)
{
    public static WindowNavigation Detached { get; } = new(() => null);
    private WindowNavigationContext? Context => Router.ContextFor(frame());
    public Window? OwnerWindow => Context is { IsClosed: false } context ? context.Window : null;
    public Guid? SessionID => Context is { IsClosed: false } context ? context.SessionID : null;
    public Guid? SavedPrayerID => OwnerWindow is PrayerWindow window ? window.SavedPrayerID : null;
    public bool CanGoBack => Context is { IsClosed: false } context
        && (context.Frame.CanGoBack || context.IsPrayerWindow);

    public void Navigate<TPage>(object? parameter = null) where TPage : Page => Navigate(typeof(TPage), parameter);
    public void Navigate(Type pageType, object? parameter = null)
    {
        if (Context is not { IsClosed: false } context) return;
        if (!context.IsPrayerWindow && DesktopWindowManager.IsPrayerPage(pageType))
        {
            DesktopWindowManager.OpenFlow(pageType, parameter);
            return;
        }
        if (!Router.IsDuplicateNavigation(context.Frame.CurrentSourcePageType, context.CurrentParameter,
            pageType, parameter)) context.Frame.Navigate(pageType, parameter);
    }

    /// <summary>A continuation gets its own identity instead of replacing the saved prayer's window.</summary>
    public void Replace<TPage>(object? parameter = null) where TPage : Page
    {
        if (Context is not { IsClosed: false } context) return;
        if (context.IsPrayerWindow && DesktopWindowManager.IsPrayerPage(typeof(TPage)))
        {
            DesktopWindowManager.OpenFlow(typeof(TPage), parameter);
            context.Window.Close();
        }
        else
        {
            Navigate<TPage>(parameter);
            context.Frame.BackStack.Clear();
        }
    }

    public void GoBack()
    {
        if (Context is not { IsClosed: false } context) return;
        if (context.Frame.CanGoBack) context.Frame.GoBack();
        else if (context.IsPrayerWindow) context.Window.Close();
    }

    public void PopToRoot()
    {
        if (Context is not { IsClosed: false } context) return;
        if (context.IsPrayerWindow) context.Window.Close();
        else while (context.Frame.CanGoBack) context.Frame.GoBack();
    }
}

internal sealed class WindowNavigationContext : IDisposable
{
    public Guid SessionID { get; } = Guid.NewGuid();
    public Frame Frame { get; }
    public Window Window { get; }
    public bool IsPrayerWindow { get; }
    public bool IsClosed { get; private set; }
    public object? CurrentParameter { get; private set; }

    public WindowNavigationContext(Frame frame, Window window, bool isPrayerWindow)
    {
        Frame = frame;
        Window = window;
        IsPrayerWindow = isPrayerWindow;
        frame.Navigated += OnNavigated;
    }
    private void OnNavigated(object sender, NavigationEventArgs args) => CurrentParameter = args.Parameter;
    public void Dispose()
    {
        IsClosed = true;
        Frame.Navigated -= OnNavigated;
    }
}
