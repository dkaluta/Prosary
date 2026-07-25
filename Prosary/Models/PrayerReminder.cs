namespace Prosary.Models;

/// <summary>A single daily reminder time attached to a <see cref="Prayer"/>. Scheduled via
/// <c>WindowsReminderScheduler</c>.</summary>
public sealed record PrayerReminder
{
    public Guid Id { get; init; } = Guid.NewGuid();

    /// <summary>0–23.</summary>
    public int Hour { get; init; }

    /// <summary>0–59.</summary>
    public int Minute { get; init; }

    public bool IsEnabled { get; init; } = true;

    public PrayerReminder() { }

    public PrayerReminder(int hour, int minute = 0, bool isEnabled = true)
    {
        Hour = hour;
        Minute = minute;
        IsEnabled = isEnabled;
    }

    public string DisplayTime => AsDate.ToString("t");

    /// <summary>A <see cref="DateTime"/> whose time-of-day matches this reminder, for use with a
    /// <c>TimePicker</c>.</summary>
    public DateTime AsDate => DateTime.Today.AddHours(Hour).AddMinutes(Minute);
}
