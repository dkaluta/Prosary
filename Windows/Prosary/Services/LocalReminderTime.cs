namespace Prosary.Services;

/// <summary>Resolve every civil day against its own zone offset, including daylight saving.</summary>
public static class LocalReminderTime
{
    public static DateTimeOffset OnDate(DateOnly date, int hour, int minute, TimeZoneInfo? zone = null)
    {
        zone ??= TimeZoneInfo.Local;
        var local = DateTime.SpecifyKind(date.ToDateTime(new TimeOnly(hour, minute)), DateTimeKind.Unspecified);
        // If the selected clock time does not exist on a spring-forward day, use the first
        // real minute afterward. Tomorrow still uses the user's original clock time.
        while (zone.IsInvalidTime(local)) local = local.AddMinutes(1);
        return new DateTimeOffset(local, zone.GetUtcOffset(local));
    }

    public static IEnumerable<DateTimeOffset> NextOccurrences(int hour, int minute, int days,
        DateTimeOffset? now = null, TimeZoneInfo? zone = null)
    {
        zone ??= TimeZoneInfo.Local;
        var current = now ?? DateTimeOffset.Now;
        var firstDate = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(current, zone).DateTime);
        if (OnDate(firstDate, hour, minute, zone) <= current) firstDate = firstDate.AddDays(1);
        for (var offset = 0; offset < days; offset++) yield return OnDate(firstDate.AddDays(offset), hour, minute, zone);
    }
}
