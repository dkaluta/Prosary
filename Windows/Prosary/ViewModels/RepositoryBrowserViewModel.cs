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
    [NotifyPropertyChangedFor(nameof(ShowsInstalledLabel))]
    [NotifyPropertyChangedFor(nameof(Title))]
    private bool _isInstalled;

    /// <summary>The repository listing is English-only, but once a bundle is installed its own
    /// manifest is on disk — so an installed row reads like the Home card it just became
    /// (Erez: his bundles' Hebrew names). Re-derived per page load, and the page reloads on
    /// every navigation, so a language change in Settings shows on the way back.</summary>
    public string Title => IsInstalled
        ? PrayerPackStore.Info(Bundle.Id)?.LocalizedDisplayName ?? Bundle.Name
        : Bundle.Name;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsInstallable))]
    [NotifyPropertyChangedFor(nameof(HasUpdate))]
    private bool _isBusy;

    /// <summary>The author republished since this copy was installed (catalog updatedAt differs
    /// from the stamp recorded at install; file imports have no stamp and never nag).</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsInstallable))]
    [NotifyPropertyChangedFor(nameof(HasUpdate))]
    [NotifyPropertyChangedFor(nameof(ShowsInstalledLabel))]
    private bool _updateAvailable;

    public bool IsInstallable => !IsInstalled && !IsBusy;

    public bool HasUpdate => UpdateAvailable && !IsBusy;

    /// <summary>The quiet "Installed" caption yields to the Update button when one is due.</summary>
    public bool ShowsInstalledLabel => IsInstalled && !UpdateAvailable;

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
/// pipeline as a manual file import. Installed rows gain the "Repository" tag and become
/// available to Categories, Search, and Pray pinning.</summary>
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

    /// <summary>The localized "All" chip — one shared instance so the tag list, the selection,
    /// and the filter comparison all agree on the same string.</summary>
    private static readonly string AllTag = Loc.Tr("browse_all", "All");

    /// <summary>"All" plus every tag the catalog uses.</summary>
    [ObservableProperty]
    private ObservableCollection<string> _tags = [AllTag];

    [ObservableProperty]
    private string _selectedTag = AllTag;

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
                UpdateAvailable = PrayerPackStore.CustomDevotionIds().Contains(bundle.Id)
                    && bundle.UpdatedAt is { } live
                    && ReadInstallStamp(bundle.Id) is { } installed
                    && live != installed,
            }).ToList();
            Tags = new ObservableCollection<string>(
                new[] { AllTag }.Concat(_all.SelectMany(r => r.Bundle.Tags).Distinct().Order()));
            SelectedTag = AllTag;
            OnPropertyChanged(nameof(ShowsTagFilter));
            ApplyFilter();
        }
        catch (TaskCanceledException timeout) when (timeout.InnerException is TimeoutException)
        {
            // HttpClient's 15 s timeout — a real outage, worth the error state.
            LoadError = Loc.Tr("browse_unreachable", "The repository could not be reached.");
        }
        catch (OperationCanceledException)
        {
            // Navigation away mid-fetch is not a repository outage — surfacing it painted
            // "unavailable / cancelled" over a perfectly healthy catalog.
        }
        catch (Exception ex)
        {
            LoadError = ex is RepositoryClient.UnsupportedCatalogException
                ? ex.Message
                : Loc.Tr("browse_unreachable", "The repository could not be reached.");
            System.Diagnostics.Debug.WriteLine($"[RepositoryBrowser] {ex}");
        }

        IsLoading = false;
    }

    private void ApplyFilter()
    {
        var query = SearchText.Trim();
        Filtered = new ObservableCollection<RepositoryRow>(_all.Where(row =>
            (SelectedTag == AllTag || row.Bundle.Tags.Contains(SelectedTag)) &&
            (query.Length == 0 ||
             $"{row.Bundle.Name} {row.Bundle.Author} {row.Bundle.Description} {row.Bundle.Id}"
                 .Contains(query, StringComparison.OrdinalIgnoreCase))));
    }

    private static string StampKey(string bundleId) => $"repoUpdatedAt.{bundleId}";

    private static string? ReadInstallStamp(string bundleId)
    {
        try
        {
            return Windows.Storage.ApplicationData.Current.LocalSettings.Values[StampKey(bundleId)] as string;
        }
        catch
        {
            return null;
        }
    }

    private static void RecordInstallStamp(string bundleId, string? updatedAt)
    {
        try
        {
            if (updatedAt is null)
            {
                Windows.Storage.ApplicationData.Current.LocalSettings.Values.Remove(StampKey(bundleId));
            }
            else
            {
                Windows.Storage.ApplicationData.Current.LocalSettings.Values[StampKey(bundleId)] = updatedAt;
            }
        }
        catch
        {
            // Settings I/O never blocks an install.
        }
    }

    [RelayCommand]
    private async Task InstallAsync(RepositoryRow row)
    {
        row.IsBusy = true;
        try
        {
            var bytes = await RepositoryClient.DownloadBundleAsync(row.Bundle);
            // InstallPack skips id collisions (shipped devotions always win), so an update
            // removes the old copy first — download succeeded, the pack-less window is tiny.
            if (row.UpdateAvailable)
            {
                PrayerPackStore.RemoveInstalledPack(row.Bundle.Id);
            }

            PrayerPackStore.InstallPack(bytes);
            row.IsInstalled = true;
            row.UpdateAvailable = false;
            RecordInstallStamp(row.Bundle.Id, row.Bundle.UpdatedAt);
        }
        catch (PrayerPackStore.InstallException ex)
        {
            InstallError = ex.Message;
        }
        catch (Exception ex)
        {
            InstallError = Loc.Tr("browse_download_failed", "The devotion could not be downloaded.");
            System.Diagnostics.Debug.WriteLine($"[RepositoryBrowser] install: {ex}");
        }

        row.IsBusy = false;
    }
}
