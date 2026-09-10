using Prosary.Navigation;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Prosary.Persistence;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>One search across local devotions and the repository — see
/// <see cref="SearchViewModel"/>. No parameter.</summary>
public sealed partial class SearchPage : Page
{
    public SearchViewModel ViewModel { get; }
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
