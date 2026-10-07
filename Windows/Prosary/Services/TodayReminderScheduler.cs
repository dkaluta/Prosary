using Prosary.Localization;
using Prosary.Models;
using System.Runtime.InteropServices;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

namespace Prosary.Services;

public static class TodayReminderScheduler
{
    public static void Refresh() => Refresh(ToastNotificationManager.CreateToastNotifier);

    internal static void Refresh(Func<ToastNotifier> createNotifier)
    {
        try
        {
            var notifier = createNotifier();
            // Disabled reminders must still remove previously scheduled deliveries.
            foreach (var old in notifier.GetScheduledToastNotifications().Where(item => item.Group == "prosary-today").ToList())
                notifier.RemoveFromSchedule(old);
            if (AppSettings.ReadingsReminderEnabled) Schedule(notifier, "readings", AppSettings.ReadingsReminderMinutes);
            if (AppSettings.SaintReminderEnabled) Schedule(notifier, "saints", AppSettings.SaintReminderMinutes);
        }
        catch (Exception error) when (error is COMException or InvalidOperationException)
        {
            // An unpackaged host or unavailable Windows notification service must
            // not prevent settings from opening. Preserve preferences for retry.
            System.Diagnostics.Debug.WriteLine($"[Today reminders] Notifications unavailable: {error}");
        }
    }

    public static string SaintBody(FeastDay feast, string calendarId, string language)
    {
        var descriptions = feast.LocalizedDescriptions(language);
        return descriptions.Count == 0 ? $"{feast.LocalizedTitle(language)} · {feast.LocalizedRank(language)}"
            : string.Join("\n\n", descriptions.Select(item => string.Join("\n",
                new[] { item.Title, item.Text, item.Credit }.Where(text => !string.IsNullOrWhiteSpace(text)))));
    }

    public static string ReadingsBody(IReadOnlyList<ReadingCitation> readings, string language, bool reverseOrder = false) =>
        string.Join("; ", ReadingCitation.DisplayOrder(readings, reverseOrder).Select(reading => reading.LocalizedFull(language)));

    private static void Schedule(ToastNotifier notifier, string kind, int minutes)
    {
        var language = UiLanguageCatalog.Current;
        foreach (var time in LocalReminderTime.NextOccurrences(minutes / 60, minutes % 60, 30))
        {
            var date = DateOnly.FromDateTime(time.DateTime);
            string title, body;
            if (kind == "readings") {
                var readings = TodayInfoStore.Readings(date);
                if (readings.Count == 0) continue;
                title = Loc.Tr("home_today_readings", "Today's readings");
                body = ReadingsBody(readings, language, AppSettings.ReverseReadingsOrder);
            } else {
                if (TodayInfoStore.Feast(date) is not { } feast) continue;
                title = feast.LocalizedTitle(language);
                body = SaintBody(feast, TodayInfoStore.ResolvedCalendarId, language);
            }
            var xml = new XmlDocument();
            var url = kind == "readings" ? "prosary://readings" : "prosary://today";
            xml.LoadXml($"<toast activationType=\"protocol\" launch=\"{url}\"><visual><binding template=\"ToastGeneric\"><text>{System.Security.SecurityElement.Escape(title)}</text><text>{System.Security.SecurityElement.Escape(body)}</text></binding></visual></toast>");
            notifier.AddToSchedule(new ScheduledToastNotification(xml, time) { Group = "prosary-today", Tag = $"{kind}-{time:yyyyMMdd}" });
        }
    }
}
