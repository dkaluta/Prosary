using Prosary.Localization;

namespace Prosary.Services;

public sealed record SearchCategory(string Id, string Label);

/// <summary>Categories use stable manifest tags across the device and community catalogs.</summary>
public static class SearchCategoryFilter
{
    public static IReadOnlyList<SearchCategory> Categories(IEnumerable<IReadOnlyList<string>> tagLists)
    {
        var ids = tagLists.SelectMany(Tags).Distinct(StringComparer.Ordinal).ToList();
        return new[] { new SearchCategory("", Loc.Tr("search_all_categories", "All Categories")) }
            .Concat(ids.Select(id => new SearchCategory(id, CategoryLabels.Display(id)))
                .OrderBy(category => category.Label, StringComparer.CurrentCultureIgnoreCase))
            .ToList();
    }

    public static bool Includes(IReadOnlyList<string> tags, string? categoryId) =>
        string.IsNullOrEmpty(categoryId) || Tags(tags).Contains(categoryId, StringComparer.Ordinal);

    private static IEnumerable<string> Tags(IReadOnlyList<string> tags)
    {
        var normalized = tags.Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Select(tag => tag.Trim().ToLowerInvariant()).ToArray();
        return normalized.Length == 0 ? ["other"] : normalized;
    }
}
