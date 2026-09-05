namespace Prosary.Localization;

/// <summary>Manifest tags remain stable identifiers; captions follow the interface language.</summary>
public static class CategoryLabels
{
    public static string Display(string tag) => tag.ToLowerInvariant() switch
    {
        "marian" => Loc.Tr("category_marian", "Marian"),
        "daily" => Loc.Tr("category_daily", "Daily"),
        "mercy" => Loc.Tr("category_mercy", "Mercy"),
        "franciscan" => Loc.Tr("category_franciscan", "Franciscan"),
        "advent" => Loc.Tr("category_advent", "Advent"),
        "meditative" => Loc.Tr("category_meditative", "Meditative"),
        "passion" => Loc.Tr("category_passion", "Passion"),
        "eastern" => Loc.Tr("category_eastern", "Eastern"),
        "short" => Loc.Tr("category_short", "Short"),
        "easter" => Loc.Tr("category_easter", "Easter"),
        "other" => Loc.Tr("category_other", "Other"),
        _ => string.IsNullOrEmpty(tag) ? string.Empty : char.ToUpper(tag[0]) + tag[1..],
    };
}
