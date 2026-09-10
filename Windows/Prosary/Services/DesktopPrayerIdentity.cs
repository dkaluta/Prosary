namespace Prosary.Services;

/// <summary>Saved copies share content but never share a desktop prayer session or series run.</summary>
public static class DesktopPrayerIdentity
{
    public static string DevotionID(string bundleID, Guid? prayerID) =>
        prayerID is { } id ? $"desktop:{id:D}:{bundleID}" : bundleID;
    public static string Saved(Guid id) => $"saved:{id:D}";
    public static string Basic(string id) => $"basic:{id}";
}
