using Prosary.Navigation;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Prosary.Persistence;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;

namespace Prosary.Views;

/// <summary>Search across prayers available on this device — see
/// <see cref="SearchViewModel"/>. No parameter.</summary>
public sealed partial class SearchPage : Page
{
    public SearchViewModel ViewModel { get; }
    public string CommunityLabel => Loc.Tr("home_widgets_community", "Community Prayers");
    private bool _focusRequested;

    public SearchPage()
    {
        ViewModel = App.Services.GetRequiredService<SearchViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        NavigationCacheMode = NavigationCacheMode.Enabled;
        Loaded += (_, _) =>
        {
            DesktopLibraryChanges.Changed += OnLibraryChanged;
            if (_focusRequested) FocusSearch();
        };
        Unloaded += (_, _) => DesktopLibraryChanges.Changed -= OnLibraryChanged;
    }

    public void FocusSearch()
    {
        _focusRequested = !IsLoaded;
        if (!IsLoaded) return;
        QueryBox.Focus(FocusState.Programmatic);
        QueryBox.SelectAll();
    }

    private void OnOpenCommunity(object sender, RoutedEventArgs e) => Router.For(this).Navigate<RepositoryBrowserPage>();

    private void OnLibraryChanged() => DispatcherQueue.TryEnqueue(() =>
    {
        if (IsLoaded) ViewModel.RefreshLocal();
    });

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }
}
