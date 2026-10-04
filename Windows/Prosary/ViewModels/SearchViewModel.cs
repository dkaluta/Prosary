using Prosary.Navigation;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>Text and category filters apply to built-in and installed prayers.</summary>
public partial class SearchViewModel : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    private readonly Func<IReadOnlyList<DevotionListing>> _localProvider;
    private IReadOnlyList<DevotionListing> _localCatalog = [];

    public SearchViewModel() : this(DevotionDirectory.All) { }

    internal SearchViewModel(Func<IReadOnlyList<DevotionListing>> localProvider)
    {
        _localProvider = localProvider;
        Categories = new ObservableCollection<SearchCategory>(SearchCategoryFilter.Categories([]));
        SelectedCategory = Categories[0];
    }

    [ObservableProperty] private string _searchText = string.Empty;
    [ObservableProperty] private ObservableCollection<SearchCategory> _categories = [];
    [ObservableProperty] private SearchCategory? _selectedCategory;
    [ObservableProperty] private ObservableCollection<DevotionListing> _localMatches = [];

    public string CategoryLabel => Loc.Tr("search_category", "Category");
    public string NoMatchesText => Loc.Tr("search_no_matches", "No prayers match this search and category.");
    public bool HasLocalMatches => LocalMatches.Count > 0;
    public bool HasNoMatches => !HasLocalMatches;

    partial void OnSearchTextChanged(string value) => ApplyFilter();
    partial void OnSelectedCategoryChanged(SearchCategory? value) => ApplyFilter();

    public Task LoadAsync()
    {
        RefreshLocal();
        return Task.CompletedTask;
    }

    public void RefreshLocal()
    {
        _localCatalog = _localProvider();
        var selectedId = SelectedCategory?.Id;
        var options = SearchCategoryFilter.Categories(_localCatalog.Select(listing => listing.Tags));
        Categories = new ObservableCollection<SearchCategory>(options.Select(option =>
            Categories.FirstOrDefault(existing => existing == option) ?? option));
        SelectedCategory = Categories.FirstOrDefault(category => category.Id == selectedId) ?? Categories[0];
        ApplyFilter();
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
        OnPropertyChanged(nameof(HasLocalMatches));
        OnPropertyChanged(nameof(HasNoMatches));
    }

    [RelayCommand] private void Open(DevotionListing listing) => listing.Launch(Navigation);
}
