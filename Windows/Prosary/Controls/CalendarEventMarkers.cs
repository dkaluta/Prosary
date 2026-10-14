using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Services;
using Windows.UI;

namespace Prosary.Controls;

/// <summary>Both native civil-date pickers mark every published event using the same source table.</summary>
public static class CalendarEventMarkers
{
    private static readonly List<WeakReference<CalendarViewDayItem>> RealizedItems = [];
    public static int EventCount(DateOnly date)
    {
        var feast = TodayInfoStore.Feast(date);
        return feast is null ? 0 : Math.Max(1, feast.Observances?.Count ?? 0);
    }

    public static void Apply(CalendarViewDayItemChangingEventArgs args)
    {
        if (!RealizedItems.Any(reference => reference.TryGetTarget(out var item) && ReferenceEquals(item, args.Item)))
            RealizedItems.Add(new(args.Item));
        Apply(args.Item);
    }

    public static void Refresh()
    {
        RealizedItems.RemoveAll(reference => !reference.TryGetTarget(out _));
        foreach (var reference in RealizedItems)
            if (reference.TryGetTarget(out var item)) Apply(item);
    }

    private static void Apply(CalendarViewDayItem item)
    {
        var count = EventCount(DateOnly.FromDateTime(item.Date.DateTime));
        var accent = Application.Current.Resources["BrandPrimaryBrush"] is SolidColorBrush brush
            ? brush.Color : Color.FromArgb(255, 23, 104, 172);
        item.SetDensityColors(Enumerable.Repeat(accent, Math.Min(count, 3)));
        AutomationProperties.SetHelpText(item, count > 0
            ? string.Format(Loc.Tr("calendar_event_count", "{0} events"), count) : "");
    }
}
