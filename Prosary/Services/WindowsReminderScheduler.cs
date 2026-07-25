using Prosary.Models;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

namespace Prosary.Services;

/// <summary>
/// Local reminder notifications via <see cref="Windows.UI.Notifications.ScheduledToastNotification"/>
/// — Windows' closest equivalent to iOS's <c>UNCalendarNotificationTrigger</c>/Android's
/// <c>AlarmManager</c>, but with a real structural difference: there is no native "repeat daily"
/// flag on this API at all (confirmed via research, not assumption — the modern
/// <c>Microsoft.Windows.AppNotifications.AppNotificationManager</c> API has no scheduling
/// capability whatsoever, only immediate <c>Show()</c>; this older
/// <c>Windows.UI.Notifications</c> API is still the only one that supports future-dated
/// notifications, and it only supports one-time delivery per scheduled instance).
///
/// Recurrence is therefore implemented as a rolling window: each enabled reminder gets the next
/// <see cref="RollingWindowDays"/> daily instances pre-scheduled at once, topped up on every app
/// launch via <see cref="RescheduleAll"/> (the Windows equivalent of Android's boot-time
/// reschedule — but on launch rather than triggered by a boot receiver, since scheduled toasts,
/// unlike AlarmManager alarms, already survive reboot on their own).
///
/// Requires a packaged (MSIX) app — unpackaged apps have documented, real toast-activation/AUMID
/// reliability problems (see the project plan for the specific issues this was decided against).
/// </summary>
public sealed class WindowsReminderScheduler : IReminderScheduler
{
    private const int RollingWindowDays = 30;

    public Task<bool> RequestPermissionAsync() => Task.FromResult(true);

    public void Schedule(Prayer prayer)
    {
        RemoveAll(prayer);

        var notifier = ToastNotificationManager.CreateToastNotifier();
        var body = NotificationBody(prayer.Kind);

        foreach (var reminder in prayer.Reminders.Where(r => r.IsEnabled))
        {
            foreach (var deliveryTime in NextOccurrences(reminder.Hour, reminder.Minute, RollingWindowDays))
            {
                var toast = BuildToast(prayer.Name, body, deliveryTime, group: prayer.Id.ToString(),
                    tag: $"{reminder.Id}-{deliveryTime:yyyyMMdd}");
                notifier.AddToSchedule(toast);
            }
        }
    }

    public void RemoveAll(Prayer prayer)
    {
        var notifier = ToastNotificationManager.CreateToastNotifier();
        var group = prayer.Id.ToString();

        // Snapshot into a list first — mutating the schedule (RemoveFromSchedule) while iterating
        // the live collection GetScheduledToastNotifications() returns is not guaranteed safe.
        var toRemove = notifier.GetScheduledToastNotifications().Where(n => n.Group == group).ToList();
        foreach (var scheduled in toRemove)
        {
            notifier.RemoveFromSchedule(scheduled);
        }
    }

    public void RescheduleAll(IEnumerable<Prayer> prayers)
    {
        foreach (var prayer in prayers)
        {
            if (prayer.Reminders.Any(r => r.IsEnabled))
            {
                Schedule(prayer);
            }
        }
    }

    private static IEnumerable<DateTimeOffset> NextOccurrences(int hour, int minute, int days)
    {
        var now = DateTimeOffset.Now;
        var first = new DateTimeOffset(now.Year, now.Month, now.Day, hour, minute, 0, now.Offset);
        if (first <= now)
        {
            first = first.AddDays(1);
        }

        for (var i = 0; i < days; i++)
        {
            yield return first.AddDays(i);
        }
    }

    // NOTE: Group/Tag lengths here (a GUID each, ~36 chars) are unverified against this API's
    // actual current length limits from this (non-Windows) environment — older Windows toast
    // APIs historically capped Tag/Group at 16 characters each, though that's believed relaxed in
    // later Windows 10+ releases. If AddToSchedule throws on a real Windows build, this is the
    // first place to look (e.g. hash/truncate the ids instead of using full GUID strings).
    private static ScheduledToastNotification BuildToast(string title, string body, DateTimeOffset deliveryTime, string group, string tag)
    {
        var xml = new XmlDocument();
        xml.LoadXml($"""
            <toast>
              <visual>
                <binding template="ToastGeneric">
                  <text>{System.Security.SecurityElement.Escape(title)}</text>
                  <text>{System.Security.SecurityElement.Escape(body)}</text>
                </binding>
              </visual>
            </toast>
            """);

        return new ScheduledToastNotification(xml, deliveryTime)
        {
            Tag = tag,
            Group = group,
        };
    }

    // Notification body text per devotion — mirrors iOS's ReminderScheduler.notificationBody(for:)
    // and Android's ReminderScheduler.kt notificationBody(kind) verbatim.
    private static string NotificationBody(PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "Time to pray the Rosary.",
        PrayerKind.Angelus => "The Angelus bell is ringing.",
        PrayerKind.JesusPrayer => "Time for the Jesus Prayer.",
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };
}
