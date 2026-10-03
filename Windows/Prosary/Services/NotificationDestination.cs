namespace Prosary.Services;

/// <summary>Notification URIs select a view only. They never mutate a prayer or accept content.</summary>
public sealed record NotificationDestination(string? Section = null, Guid? PrayerId = null)
{
    public static NotificationDestination? Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Contains('%') || value.Contains('\\')
            || !Uri.TryCreate(value, UriKind.Absolute, out var uri)
            || !uri.Scheme.Equals("prosary", StringComparison.OrdinalIgnoreCase)
            || !string.IsNullOrEmpty(uri.UserInfo) || uri.Port != -1
            || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment)) return null;
        if ((uri.Host is "today" or "readings") && (uri.AbsolutePath is "" or "/")
            && (value.Equals($"prosary://{uri.Host}", StringComparison.OrdinalIgnoreCase)
                || value.Equals($"prosary://{uri.Host}/", StringComparison.OrdinalIgnoreCase)))
            return new NotificationDestination(Section: uri.Host);
        if (uri.Host == "prayer" && Guid.TryParseExact(uri.AbsolutePath.TrimStart('/'), "D", out var id)
            && value.Equals($"prosary://prayer/{id:D}", StringComparison.OrdinalIgnoreCase))
            return new NotificationDestination(PrayerId: id);
        return null;
    }
}
