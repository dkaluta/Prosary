using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>One card in the repository browser — the catalog entry plus its install state.</summary>
public partial class RepositoryRow : ObservableObject
{
    public required RepositoryBundle Bundle { get; init; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsInstallable))]
    private bool _isInstalled;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsInstallable))]
    private bool _isBusy;

    public bool IsInstallable => !IsInstalled && !IsBusy;

    public string Subtitle
    {
        get
        {
            var names = Bundle.Languages
                .Select(code => LanguageCatalog.All.FirstOrDefault(l => l.Code == code)?.NativeName)
                .Where(n => n is not null);
            return $"{Bundle.Author} · {string.Join(", ", names)}";
        }
    }

    public string TagsLine => string.Join(" · ", Bundle.Tags);

    public bool HasTags => Bundle.Tags.Count > 0;

    public bool HasDescription => Bundle.Description.Length > 0;
}

/// <summary>The in-app browser for prayers.prosary.app: fetches the catalog, filters by search
/// text and tag, and installs through the exact same <see cref="PrayerPackStore.InstallPack"/>
/// pipeline as a manual file import — so an installed community devotion behaves identically
/// (star row, "Repository" tag, remove affordance). Mirrors iOS's RepositoryBrowserView.</summary>
public partial class RepositoryBrowserViewModel : ObservableObject
{
    private IReadOnlyList<RepositoryRow> _all = [];

    [ObservableProperty]
    private bool _isLoading = true;

    [ObservableProperty]
    private string? _loadError;

    [ObservableProperty]
    private string? _installError;

    [ObservableProperty]
    private string _searchText = string.Empty;

    /// <summary>"All" plus every tag the catalog uses.</summary>
    [ObservableProperty]
    private ObservableCollection<string> _tags = ["All"];

    [ObservableProperty]
    private string _selectedTag = "All";

    [ObservableProperty]
    private ObservableCollection<RepositoryRow> _filtered = [];

    public bool ShowsTagFilter => Tags.Count > 2;

    partial void OnSearchTextChanged(string value) => ApplyFilter();

    partial void OnSelectedTagChanged(string value) => ApplyFilter();

    [RelayCommand]
    public async Task LoadAsync()
    {
        IsLoading = true;
        LoadError = null;
        try
        {
            var catalog = await RepositoryClient.FetchCatalogAsync();
            _all = catalog.Select(bundle => new RepositoryRow
            {
                Bundle = bundle,
                IsInstalled = PrayerPackStore.CustomDevotionIds().Contains(bundle.Id),
            }).ToList();
            Tags = new ObservableCollection<string>(
                new[] { "All" }.Concat(_all.SelectMany(r => r.Bundle.Tags).Distinct().Order()));
            SelectedTag = "All";
            OnPropertyChanged(nameof(ShowsTagFilter));
            ApplyFilter();
        }
        catch (Exception ex)
        {
            LoadError = ex is RepositoryClient.UnsupportedCatalogException
                ? ex.Message
                : "The repository could not be reached.";
            System.Diagnostics.Debug.WriteLine($"[RepositoryBrowser] {ex}");
        }

        IsLoading = false;
    }

    private void ApplyFilter()
    {
        var query = SearchText.Trim();
        Filtered = new ObservableCollection<RepositoryRow>(_all.Where(row =>
            (SelectedTag == "All" || row.Bundle.Tags.Contains(SelectedTag)) &&
            (query.Length == 0 ||
             $"{row.Bundle.Name} {row.Bundle.Author} {row.Bundle.Description} {row.Bundle.Id}"
                 .Contains(query, StringComparison.OrdinalIgnoreCase))));
    }

    [RelayCommand]
    private async Task InstallAsync(RepositoryRow row)
    {
        row.IsBusy = true;
        try
        {
            var bytes = await RepositoryClient.DownloadBundleAsync(row.Bundle);
            PrayerPackStore.InstallPack(bytes);
            row.IsInstalled = true;
        }
        catch (PrayerPackStore.InstallException ex)
        {
            InstallError = ex.Message;
        }
        catch (Exception ex)
        {
            InstallError = "The devotion could not be downloaded.";
            System.Diagnostics.Debug.WriteLine($"[RepositoryBrowser] install: {ex}");
        }

        row.IsBusy = false;
    }
}
