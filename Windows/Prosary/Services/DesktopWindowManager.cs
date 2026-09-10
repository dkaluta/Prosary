using Microsoft.Extensions.DependencyInjection;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Views;

namespace Prosary.Services;

/// <summary>Keeps native windows alive and reuses only the exact requested saved copy.</summary>
public static class DesktopWindowManager
{
    private static MainWindow? _library;
    private static readonly Dictionary<string, PrayerWindow> PrayerWindows = new();
    private static bool _observing;
    private static Microsoft.UI.Dispatching.DispatcherQueue? _dispatcher;

    public static void ShowLibrary(string section = "library")
    {
        ObserveLibrary();
        if (_library is null)
        {
            var window = new MainWindow();
            _library = window;
            App.MainWindow = window;
            window.Closed += (_, _) => { if (_library == window) _library = null; };
        }
        _library.SelectSection(section);
        _library.Activate();
    }

    public static async Task OpenPrayerAsync(Guid prayerID)
    {
        var prayer = await App.Services.GetRequiredService<IPresetStore>().GetAsync(prayerID);
        if (prayer is null) { ShowLibrary(); return; }
        switch (prayer.Kind)
        {
            case PrayerKind.Rosary: OpenFlow(typeof(RosaryPrayerPage), prayer.Id); break;
            case PrayerKind.JesusPrayer:
                OpenFlow(typeof(JesusPrayerFlowPage), new JesusPrayerFlowParams(prayer.Id, null)); break;
            case PrayerKind.Custom when prayer.CustomDevotionId is { } bundleID:
                OpenFlow(typeof(CustomDevotionFlowPage), new CustomDevotionFlowParams(prayer.Id, bundleID)); break;
        }
    }

    public static void OpenBasicPrayer(string id) => OpenFlow(typeof(BasicPrayerFlowPage), id);
    public static bool IsPrayerPage(Type type) => type == typeof(RosaryPrayerPage)
        || type == typeof(CustomDevotionFlowPage) || type == typeof(JesusPrayerFlowPage)
        || type == typeof(JesusPrayerSetupPage) || type == typeof(BasicPrayerFlowPage);

    public static void OpenFlow(Type pageType, object? parameter)
    {
        if (!IsPrayerPage(pageType)) throw new ArgumentException("Expected a prayer page.", nameof(pageType));
        ObserveLibrary();
        var savedID = SavedPrayerID(pageType, parameter);
        var identity = savedID is { } id ? DesktopPrayerIdentity.Saved(id)
            : pageType == typeof(BasicPrayerFlowPage) && parameter is string basicID
                ? DesktopPrayerIdentity.Basic(basicID) : $"session:{Guid.NewGuid():D}";
        if (PrayerWindows.TryGetValue(identity, out var existing)) { existing.Activate(); return; }
        var window = new PrayerWindow(pageType, parameter, savedID);
        PrayerWindows.Add(identity, window);
        window.Closed += (_, _) =>
        {
            foreach (var key in PrayerWindows.Where(pair => ReferenceEquals(pair.Value, window)).Select(pair => pair.Key).ToArray())
                PrayerWindows.Remove(key);
        };
        window.Activate();
    }

    public static void AdoptSavedPrayer(Microsoft.UI.Xaml.Window? owner, Guid id)
    {
        if (owner is not PrayerWindow window) return;
        var savedKey = DesktopPrayerIdentity.Saved(id);
        if (PrayerWindows.TryGetValue(savedKey, out var existing) && !ReferenceEquals(existing, window))
        {
            existing.Activate();
            window.Close();
            return;
        }
        var oldKey = PrayerWindows.FirstOrDefault(pair => ReferenceEquals(pair.Value, window)).Key;
        if (oldKey is null) return;
        PrayerWindows.Remove(oldKey);
        PrayerWindows[savedKey] = window;
        window.AdoptSavedPrayer(id);
    }

    internal static Guid? SavedPrayerID(Type pageType, object? parameter) => parameter switch
    {
        Guid id when pageType == typeof(RosaryPrayerPage) => id,
        CustomDevotionFlowParams custom => custom.PrayerId,
        JesusPrayerFlowParams jesus => jesus.PrayerId,
        _ => null,
    };

    private static void ObserveLibrary()
    {
        if (_observing) return;
        _observing = true;
        _dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        DesktopLibraryChanges.Deleted += id => _dispatcher?.TryEnqueue(() =>
        {
            if (PrayerWindows.TryGetValue(DesktopPrayerIdentity.Saved(id), out var window)) window.Close();
        });
        DesktopLibraryChanges.Changed += () => _dispatcher?.TryEnqueue(() =>
        {
            foreach (var window in PrayerWindows.Values.ToArray()) _ = window.RefreshTitleAsync();
        });
    }
}
