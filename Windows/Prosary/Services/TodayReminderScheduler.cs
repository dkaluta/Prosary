using Prosary.Localization;
using Prosary.Models;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

namespace Prosary.Services;

public static class TodayReminderScheduler
{
    public static void Refresh()
    {
        var notifier = ToastNotificationManager.CreateToastNotifier();
        foreach (var old in notifier.GetScheduledToastNotifications().Where(item => item.Group == "prosary-today").ToList())
            notifier.RemoveFromSchedule(old);
        if (AppSettings.ReadingsReminderEnabled) Schedule("readings", AppSettings.ReadingsReminderMinutes);
        if (AppSettings.SaintReminderEnabled) Schedule("saints", AppSettings.SaintReminderMinutes);
    }

    public static string SaintBody(FeastDay feast, string calendarId, string language)
    {
        var descriptions = feast.LocalizedDescriptions(language);
        return descriptions.Count == 0 ? $"{feast.LocalizedTitle(language)} · {feast.LocalizedRank(language)}"
            : string.Join("\n\n", descriptions.Select(item => string.Join("\n",
                new[] { item.Title, item.Text, item.Credit }.Where(text => !string.IsNullOrWhiteSpace(text)))));
    }

    private static void Schedule(string kind, int minutes)
    {
        var notifier = ToastNotificationManager.CreateToastNotifier();
        var language = UiLanguageCatalog.Current;
        foreach (var time in LocalReminderTime.NextOccurrences(minutes / 60, minutes % 60, 30))
        {
            var date = DateOnly.FromDateTime(time.DateTime);
            string title, body;
            if (kind == "readings") {
                var readings = TodayInfoStore.Readings(date);
                if (readings.Count == 0) continue;
                title = Loc.Tr("home_today_readings", "Today's readings");
                body = string.Join("; ", readings.Select(reading => reading.LocalizedFull(language)));
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
