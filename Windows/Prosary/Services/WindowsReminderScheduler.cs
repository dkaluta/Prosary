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
        var body = NotificationBody(prayer);

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

    /// <summary>A series in progress earns one toast per remaining day — the spec's "a
    /// notification per day prompting you to continue" — rather than a rolling daily window that
    /// would keep nagging after the last day. Rewritten from scratch on every call, so recording
    /// a day, starting over, or finishing the run all leave exactly the right ones scheduled.
    /// Mirrors iOS's RefreshSeries.</summary>
    public void RefreshSeries(string devotionId)
    {
        var notifier = ToastNotificationManager.CreateToastNotifier();
        var group = SeriesGroup(devotionId);

        var stale = notifier.GetScheduledToastNotifications().Where(n => n.Group == group).ToList();
        foreach (var scheduled in stale)
        {
            notifier.RemoveFromSchedule(scheduled);
        }

        var definition = Localization.PrayerPackStore.Definition(devotionId);
        var days = definition?.Days;
        if (days is null || days.Count <= 1 || (definition!.DayProgression ?? "series") != "series")
        {
            return;
        }

        if (MultiDayRuns.Run(devotionId) is not { } run || run.IsComplete(days.Count))
        {
            return;
        }

        var (hour, minute) = ReminderTime(definition.SuggestedReminderTime);
        var title = Localization.PrayerPackStore.Info(devotionId)?.LocalizedDisplayName ?? devotionId;

        foreach (var (day, deliveryTime) in PendingSeriesDays(run, days.Count, hour, minute))
        {
            var body = string.Format(
                Localization.Loc.Tr("multi_day_reminder_body", "Day {0} of {1} awaits."),
                day + 1, days.Count);
            notifier.AddToSchedule(BuildToast(title, body, deliveryTime, group, tag: $"day-{day}"));
        }
    }

    /// <summary>Which days still deserve a prompt and when: each unprayed day on the calendar
    /// date the run puts it on, skipping anything already past. Pure, so the dates are
    /// testable.</summary>
    public static List<(int Day, DateTimeOffset When)> PendingSeriesDays(
        MultiDayRun run, int dayCount, int hour, int minute, DateTimeOffset? now = null)
    {
        var today = now ?? DateTimeOffset.Now;
        var start = run.StartedOn;
        var pending = new List<(int, DateTimeOffset)>();

        for (var day = 0; day < dayCount; day++)
        {
            if (run.PrayedDays.Contains(day))
            {
                continue;
            }

            var midnight = start.Date.AddDays(day);
            var fire = new DateTimeOffset(midnight.AddHours(hour).AddMinutes(minute), start.Offset);
            if (fire > today)
            {
                pending.Add((day, fire));
            }
        }

        return pending;
    }

    /// <summary>The bundle's suggested "HH:mm", or early evening — when the day's prayer is
    /// traditionally said and, failing that, when someone is most likely free to say it.</summary>
    public static (int Hour, int Minute) ReminderTime(string? suggested)
    {
        var parts = suggested?.Split(':');
        if (parts is { Length: 2 } &&
            int.TryParse(parts[0], out var hour) && hour is >= 0 and <= 23 &&
            int.TryParse(parts[1], out var minute) && minute is >= 0 and <= 59)
        {
            return (hour, minute);
        }

        return (18, 0);
    }

    private static string SeriesGroup(string devotionId) => $"series-{devotionId}";

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

    // Notification body text per devotion — mirrors iOS/Android: a generic devotion's body
    // comes from its bundle manifest's reminderBody (e.g. the Angelus's bell text), not any
    // hardcoded per-kind table. The body is baked into each scheduled toast, so a toast armed
    // before an app update keeps its old body until re-armed (next launch's RescheduleAll).
    private static string NotificationBody(Prayer prayer) => prayer.Kind switch
    {
        PrayerKind.Rosary => Localization.Loc.Tr("reminder_rosary", "Time to pray the Rosary."),
        PrayerKind.JesusPrayer => Localization.Loc.Tr("reminder_jesus", "Time for the Jesus Prayer."),
        PrayerKind.Custom => prayer.CustomDevotionId is { } bundleId
            ? Localization.PrayerPackStore.Info(bundleId)?.LocalizedReminderBody ?? Localization.Loc.Tr("reminder_pray", "Time to pray.")
            : Localization.Loc.Tr("reminder_pray", "Time to pray."),
        _ => throw new ArgumentOutOfRangeException(nameof(prayer))
    };
}
