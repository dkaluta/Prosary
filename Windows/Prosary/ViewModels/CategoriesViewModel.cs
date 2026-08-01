using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record CategorySection(string Title, IReadOnlyList<DevotionListing> Listings);

/// <summary>"View prayers by category": every launchable devotion grouped by its manifest
/// tags — a devotion appears under each of its tags; anything untagged lands under "Other".
/// Mirrors iOS's CategoriesView.</summary>
public partial class CategoriesViewModel : ObservableObject
{
    [ObservableProperty]
    private ObservableCollection<CategorySection> _sections = [];

    public void Load()
    {
        var byTag = new SortedDictionary<string, List<DevotionListing>>();
        foreach (var listing in DevotionDirectory.All())
        {
            if (listing.Tags.Count == 0)
            {
                (byTag.TryGetValue("other", out var other) ? other : byTag["other"] = []).Add(listing);
            }
            foreach (var tag in listing.Tags)
            {
                (byTag.TryGetValue(tag, out var list) ? list : byTag[tag] = []).Add(listing);
            }
        }
        Sections = new ObservableCollection<CategorySection>(
            byTag.Select(pair => new CategorySection(
                char.ToUpperInvariant(pair.Key[0]) + pair.Key[1..], pair.Value)));
    }

    [RelayCommand]
    private void Open(DevotionListing listing) => listing.Launch();
}
