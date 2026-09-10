using Prosary.Navigation;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Persistence;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>Text and category filters apply together to local and community prayers.</summary>
public partial class SearchViewModel : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    private readonly Func<IReadOnlyList<DevotionListing>> _localProvider;
    private readonly Func<Task<IReadOnlyList<RepositoryBundle>>> _communityProvider;
    private readonly Func<HashSet<string>> _installedProvider;
    private IReadOnlyList<DevotionListing> _localCatalog = [];
    private IReadOnlyList<RepositoryBundle> _catalog = [];
    private Task? _catalogLoad;
    private bool _catalogLoaded;

    public SearchViewModel() : this(DevotionDirectory.All, RepositoryClient.FetchCatalogAsync,
        () => PrayerPackStore.CustomDevotionIds().ToHashSet()) { }

    internal SearchViewModel(Func<IReadOnlyList<DevotionListing>> localProvider,
        Func<Task<IReadOnlyList<RepositoryBundle>>> communityProvider, Func<HashSet<string>> installedProvider)
    {
        _localProvider = localProvider;
        _communityProvider = communityProvider;
        _installedProvider = installedProvider;
        Categories = new ObservableCollection<SearchCategory>(SearchCategoryFilter.Categories([]));
        SelectedCategory = Categories[0];
    }

    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private ObservableCollection<SearchCategory> _categories = [];

    [ObservableProperty]
    private SearchCategory? _selectedCategory;

    [ObservableProperty]
    private ObservableCollection<DevotionListing> _localMatches = [];

    [ObservableProperty]
    private ObservableCollection<RepositoryRow> _communityMatches = [];

    [ObservableProperty]
    private string? _installError;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasNoMatches))]
    private bool _isLoadingCatalog;

    public string CategoryLabel => Loc.Tr("search_category", "Category");
    public string NoMatchesText => Loc.Tr("search_no_matches", "No prayers match this search and category.");
    public bool HasLocalMatches => LocalMatches.Count > 0;
    public bool HasCommunityMatches => CommunityMatches.Count > 0;
    public bool HasNoMatches => !IsLoadingCatalog && !HasLocalMatches && !HasCommunityMatches;

    partial void OnSearchTextChanged(string value) => ApplyFilter();
    partial void OnSelectedCategoryChanged(SearchCategory? value) => ApplyFilter();

    public async Task LoadAsync()
    {
        RefreshLocal();
        if (_catalogLoaded) return;
        if (_catalogLoad is not null) { await _catalogLoad; return; }
        var load = LoadCommunityAsync();
        _catalogLoad = load;
        try { await load; }
        finally { if (ReferenceEquals(_catalogLoad, load)) _catalogLoad = null; }
    }

    public void RefreshLocal()
    {
        _localCatalog = _localProvider();
        RefreshCategories();
        ApplyFilter();
    }

    private async Task LoadCommunityAsync()
    {
        IsLoadingCatalog = true;
        try
        {
            _catalog = await _communityProvider();
            _catalogLoaded = true;
        }
        catch
        {
            _catalog = [];
        }
        finally
        {
            IsLoadingCatalog = false;
        }
        RefreshCategories();
        ApplyFilter();
    }

    private void RefreshCategories()
    {
        var selectedId = SelectedCategory?.Id;
        var installed = _installedProvider();
        var options = SearchCategoryFilter.Categories(_localCatalog.Select(listing => listing.Tags)
            .Concat(_catalog.Where(bundle => !installed.Contains(bundle.Id)).Select(bundle => (IReadOnlyList<string>)bundle.Tags)));
        // Retain object identity so the native picker keeps its selection while its list refreshes.
        Categories = new ObservableCollection<SearchCategory>(options.Select(option =>
            Categories.FirstOrDefault(existing => existing == option) ?? option));
        SelectedCategory = Categories.FirstOrDefault(category => category.Id == selectedId) ?? Categories[0];
    }

    private void ApplyFilter()
    {
        var query = SearchText.Trim();
        var category = SelectedCategory?.Id;
        LocalMatches = new ObservableCollection<DevotionListing>(
            _localCatalog.Where(listing => SearchCategoryFilter.Includes(listing.Tags, category))
                .Where(listing => query.Length == 0
                    || listing.Title.Contains(query, StringComparison.OrdinalIgnoreCase)
                    || listing.InterfaceSubtitle.Contains(query, StringComparison.OrdinalIgnoreCase)
                    || listing.Tags.Any(tag => tag.Contains(query, StringComparison.OrdinalIgnoreCase)
                        || CategoryLabels.Display(tag).Contains(query, StringComparison.OrdinalIgnoreCase))));

        var installed = _installedProvider();
        CommunityMatches = new ObservableCollection<RepositoryRow>(
            _catalog.Where(bundle => !installed.Contains(bundle.Id))
                .Where(bundle => SearchCategoryFilter.Includes(bundle.Tags, category))
                .Where(bundle => query.Length == 0
                    || $"{bundle.Name} {bundle.Author} {bundle.Description} {string.Join(' ', bundle.Tags)} {string.Join(' ', bundle.Tags.Select(CategoryLabels.Display))}"
                        .Contains(query, StringComparison.OrdinalIgnoreCase))
                .Select(bundle => new RepositoryRow { Bundle = bundle }));
        OnPropertyChanged(nameof(HasLocalMatches));
        OnPropertyChanged(nameof(HasCommunityMatches));
        OnPropertyChanged(nameof(HasNoMatches));
    }

    [RelayCommand]
    private void Open(DevotionListing listing) => listing.Launch(Navigation);

    [RelayCommand]
    private async Task InstallAsync(RepositoryRow row)
    {
        row.IsBusy = true;
        InstallError = null;
        try
        {
            var bytes = await RepositoryClient.DownloadBundleAsync(row.Bundle);
            PrayerPackStore.InstallPack(bytes);
            RefreshLocal();
            DesktopLibraryChanges.Publish();
        }
        catch (PrayerPackStore.InstallException ex)
        {
            InstallError = ex.Message;
        }
        catch (Exception ex)
        {
            InstallError = Loc.Tr("browse_download_failed", "The devotion could not be downloaded.");
            System.Diagnostics.Debug.WriteLine($"[Search] install: {ex}");
        }
        row.IsBusy = false;
    }
}
