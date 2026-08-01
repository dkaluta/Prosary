using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>One search across everything prayable: devotions on this device (opened in place)
/// and the prayers.prosary.app catalog (installed in place). The repository half loads once
/// and degrades silently offline, leaving local search fully working. Mirrors iOS's
/// SearchTabView.</summary>
public partial class SearchViewModel : ObservableObject
{
    private IReadOnlyList<RepositoryBundle> _catalog = [];

    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private ObservableCollection<DevotionListing> _localMatches = [];

    [ObservableProperty]
    private ObservableCollection<RepositoryRow> _communityMatches = [];

    [ObservableProperty]
    private string? _installError;

    public bool HasCommunityMatches => CommunityMatches.Count > 0;

    partial void OnSearchTextChanged(string value) => ApplyFilter();

    public async Task LoadAsync()
    {
        try
        {
            _catalog = await RepositoryClient.FetchCatalogAsync();
        }
        catch
        {
            _catalog = [];
        }
        ApplyFilter();
    }

    private void ApplyFilter()
    {
        var query = SearchText.Trim();

        LocalMatches = new ObservableCollection<DevotionListing>(
            DevotionDirectory.All().Where(listing =>
                query.Length == 0
                || listing.Title.Contains(query, StringComparison.OrdinalIgnoreCase)
                || listing.Tags.Any(t => t.Contains(query, StringComparison.OrdinalIgnoreCase))));

        var installed = PrayerPackStore.CustomDevotionIds().ToHashSet();
        CommunityMatches = new ObservableCollection<RepositoryRow>(
            _catalog
                .Where(bundle => !installed.Contains(bundle.Id))
                .Where(bundle =>
                    query.Length == 0
                    || $"{bundle.Name} {bundle.Author} {bundle.Description} {string.Join(' ', bundle.Tags)}"
                        .Contains(query, StringComparison.OrdinalIgnoreCase))
                .Select(bundle => new RepositoryRow { Bundle = bundle }));
        OnPropertyChanged(nameof(HasCommunityMatches));
    }

    [RelayCommand]
    private void Open(DevotionListing listing) => listing.Launch();

    [RelayCommand]
    private async Task InstallAsync(RepositoryRow row)
    {
        row.IsBusy = true;
        try
        {
            var bytes = await RepositoryClient.DownloadBundleAsync(row.Bundle);
            PrayerPackStore.InstallPack(bytes);
            ApplyFilter();
        }
        catch (PrayerPackStore.InstallException ex)
        {
            InstallError = ex.Message;
        }
        catch (Exception ex)
        {
            InstallError = "The devotion could not be downloaded.";
            System.Diagnostics.Debug.WriteLine($"[Search] install: {ex}");
        }
        row.IsBusy = false;
    }
}
