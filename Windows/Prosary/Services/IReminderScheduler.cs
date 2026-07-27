using Prosary.Models;

namespace Prosary.Services;

/// <summary>Schedules/cancels daily local reminder notifications for a <see cref="Prayer"/>'s
/// saved reminders.</summary>
public interface IReminderScheduler
{
    /// <summary>Windows has no interactive notification-permission prompt to gate on (unlike
    /// iOS/Android 13+), so a real implementation can treat this as always-granted — kept as an
    /// async bool for interface parity with iOS/Android and in case a future Windows API adds one.</summary>
    Task<bool> RequestPermissionAsync();

    /// <summary>Replaces all pending reminders for <paramref name="prayer"/> with its current
    /// enabled reminders.</summary>
    void Schedule(Prayer prayer);

    /// <summary>Removes all pending reminders for <paramref name="prayer"/>.</summary>
    void RemoveAll(Prayer prayer);

    /// <summary>Re-schedules every enabled reminder across every favorite — called at app launch
    /// to top up the rolling notification window (see <c>WindowsReminderScheduler</c>), since
    /// scheduled toasts are pre-materialized a fixed number of days ahead rather than being a
    /// true recurring trigger the way iOS's UNCalendarNotificationTrigger is.</summary>
    void RescheduleAll(IEnumerable<Prayer> prayers);
}
