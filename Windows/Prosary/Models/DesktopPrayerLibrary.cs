using Prosary.Localization;

namespace Prosary.Models;

public sealed record DesktopPrayerItem(Prayer Prayer)
{
    public Guid Id => Prayer.Id;
    public string Title => Prayer.DisplayName;
    public string Subtitle => Prayer.FavoriteSubtitle;
    public string ImageUri => DesktopPrayerLibrary.ImageUri(DesktopPrayerLibrary.DevotionId(Prayer));
}

public sealed record DesktopGalleryItem(string Id, string Title, string Subtitle, string ImageUri);

/// <summary>Library operations create saved copies; gallery templates are never edited in place.</summary>
public static class DesktopPrayerLibrary
{
    public static string DevotionId(Prayer prayer) => prayer.Kind switch
    {
        PrayerKind.Rosary => "rosary",
        PrayerKind.JesusPrayer => "jesusPrayer",
        _ => prayer.CustomDevotionId ?? ""
    };

    public static string ImageUri(string id) => PrayerPackStore.ImageFileUriOrPlaceholder("gallery_" + id);

    public static IReadOnlyList<DesktopGalleryItem> Gallery()
    {
        var ids = new[] { "rosary" }.Concat(PrayerPackStore.CustomDevotionIds())
            .Concat(new[] { "jesusPrayer" }).Distinct();
        return ids.Select(id =>
        {
            var info = PrayerPackStore.Info(id);
            var title = info?.LocalizedDisplayName ?? (id == "jesusPrayer"
                ? Loc.Tr("kind_jesus_prayer", "Jesus Prayer")
                : Loc.Tr("kind_rosary", "Rosary"));
            var subtitle = info is null ? "" : string.Join(" · ", info.Tags.Select(tag =>
                Loc.Tr("category_" + tag, tag)));
            return new DesktopGalleryItem(id, title, subtitle, ImageUri(id));
        }).ToList();
    }

    public static Prayer Create(DesktopGalleryItem template, IReadOnlyList<Prayer> existing)
    {
        var kind = template.Id switch
        {
            "rosary" => PrayerKind.Rosary,
            "jesusPrayer" => PrayerKind.JesusPrayer,
            _ => PrayerKind.Custom
        };
        return new Prayer
        {
            Name = UniqueName(template.Title, existing.Select(prayer => prayer.Name)),
            Kind = kind,
            CustomDevotionId = kind == PrayerKind.Custom ? template.Id : null,
            IsDefault = !existing.Any(prayer => DevotionId(prayer) == template.Id)
        };
    }

    public static Prayer Duplicate(Prayer source, IEnumerable<string> existingNames) => source with
    {
        Id = Guid.NewGuid(),
        Name = UniqueName(string.Format(Loc.Tr("desktop_copy_name", "{0} copy"), source.Name), existingNames),
        IsDefault = false,
        CustomOptions = new Dictionary<string, string>(source.CustomOptions),
        Reminders = source.Reminders.Select(reminder => reminder with { Id = Guid.NewGuid(), IsEnabled = false }).ToList()
    };

    public static string UniqueName(string proposed, IEnumerable<string> existingNames)
    {
        var names = existingNames.ToHashSet(StringComparer.CurrentCultureIgnoreCase);
        if (!names.Contains(proposed)) return proposed;
        var suffix = 2;
        while (names.Contains($"{proposed} ({suffix})")) suffix++;
        return $"{proposed} ({suffix})";
    }
}
