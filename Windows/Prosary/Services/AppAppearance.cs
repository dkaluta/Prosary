using Microsoft.UI.Dispatching;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Applies the shared palette to every live window without changing its navigation.</summary>
internal static class AppAppearance
{
    private sealed record WindowAppearance(FrameworkElement Root, AppWindow Window);
    private static readonly List<WindowAppearance> Windows = [];
    private static DispatcherQueue? _dispatcher;

    public static void Initialize()
    {
        if (_dispatcher is not null) return;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        ApplyResources();
        AppSettings.AppColorChanged += () => _dispatcher.TryEnqueue(RefreshWindows);
    }

    public static void Attach(Window owner, FrameworkElement root, AppWindow window)
    {
        var appearance = new WindowAppearance(root, window);
        Windows.Add(appearance);
        ApplyIcon(window);
        owner.Closed += (_, _) => Windows.Remove(appearance);
    }

    private static void RefreshWindows()
    {
        ApplyResources();
        foreach (var appearance in Windows.ToArray())
        {
            // Re-evaluate native ThemeResource references while retaining the user's OS theme.
            // Both assignments occur in one UI dispatch, without replacing the page or window.
            var requested = appearance.Root.RequestedTheme;
            appearance.Root.RequestedTheme = appearance.Root.ActualTheme == ElementTheme.Dark
                ? ElementTheme.Light : ElementTheme.Dark;
            appearance.Root.RequestedTheme = requested;
            ApplyIcon(appearance.Window);
        }
    }

    private static void ApplyResources()
    {
        var palette = AppColorPalette.Resolve(AppSettings.AppColor);
        var resources = Application.Current.Resources;
        foreach (var theme in new[] { "Light", "Dark" })
        {
            if (resources.ThemeDictionaries[theme] is not ResourceDictionary values) continue;
            var accent = palette.Accent(theme == "Dark");
            values["BrandPrimaryColor"] = accent;
            values["BrandHeadlineColor"] = accent;
            foreach (var key in new[] { "BrandPrimaryBrush", "BrandPrimaryFaintBrush", "BrandHeadlineBrush" })
                if (values[key] is SolidColorBrush brush) brush.Color = accent;
            values["SystemAccentColor"] = accent;
            // Fluent uses the dark shades against light surfaces and light shades against
            // dark surfaces. Opacity states remain owned by its native control templates.
            foreach (var level in new[] { 1, 2, 3 })
            {
                values[$"SystemAccentColorDark{level}"] = palette.Accent(false);
                values[$"SystemAccentColorLight{level}"] = palette.Accent(true);
            }
        }
        // HighContrast is deliberately untouched: its brushes resolve Windows system colors.
    }

    private static void ApplyIcon(AppWindow window)
    {
        var name = AppColorPalette.Resolve(AppSettings.AppColor).IconFileName;
        var path = Path.Combine(AppContext.BaseDirectory, "Assets", "Icons", name);
        if (!File.Exists(path)) return;
        try { window.SetIcon(path); }
        catch (Exception error) { System.Diagnostics.Debug.WriteLine(error); }
    }
}
