using System.Collections.Specialized;
using System.ComponentModel;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media.Imaging;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Windows.System;

namespace Prosary.Views;

public sealed partial class DesktopGalleryPage : Page
{
    public DesktopLibraryViewModel ViewModel { get; }
    private bool _isActive;
    private bool _didLoad;
    private bool _dialogOpen;
    private bool _reloadPending;
    private static readonly Uri PlaceholderArtwork = new("ms-appx:///Assets/Images/cross_placeholder.png");

    public DesktopGalleryPage()
    {
        ViewModel = App.Services.GetRequiredService<DesktopLibraryViewModel>();
        InitializeComponent();
        FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        UpdateActions();
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_isActive) return;
        _isActive = true;
        ViewModel.Navigation = Router.For(this);
        ViewModel.ShowError = ShowErrorAsync;
        ViewModel.PropertyChanged += OnViewModelChanged;
        ViewModel.Gallery.CollectionChanged += OnGalleryChanged;
        DesktopLibraryChanges.Changed += OnLibraryChanged;
        await ViewModel.LoadAsync();
        _didLoad = true;
        UpdateActions();
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        _isActive = false;
        _reloadPending = false;
        DesktopLibraryChanges.Changed -= OnLibraryChanged;
        ViewModel.PropertyChanged -= OnViewModelChanged;
        ViewModel.Gallery.CollectionChanged -= OnGalleryChanged;
        ViewModel.ShowError = null;
    }

    private void OnLibraryChanged() => DispatcherQueue.TryEnqueue(async () =>
    {
        if (!_isActive) return;
        // Mutations refresh their own list and choose the new copy before external refreshes.
        if (ViewModel.IsBusy) { _reloadPending = true; return; }
        _reloadPending = false;
        await ViewModel.LoadAsync();
    });

    private void OnGalleryChanged(object? sender, NotifyCollectionChangedEventArgs e) => UpdateActions();

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ViewModel.IsBusy) && !ViewModel.IsBusy && _reloadPending)
            OnLibraryChanged();
        if (e.PropertyName is nameof(ViewModel.SelectedTemplate) or nameof(ViewModel.IsBusy)) UpdateActions();
        if (e.PropertyName == nameof(ViewModel.StatusMessage) && !string.IsNullOrWhiteSpace(ViewModel.StatusMessage))
        {
            DispatcherQueue.TryEnqueue(() =>
            {
                if (!_isActive) return;
                var peer = FrameworkElementAutomationPeer.FromElement(StatusText)
                    ?? FrameworkElementAutomationPeer.CreatePeerForElement(StatusText);
                peer?.RaiseAutomationEvent(AutomationEvents.LiveRegionChanged);
            });
        }
    }

    private void UpdateActions()
    {
        AddButton.IsEnabled = ViewModel.SelectedTemplate is not null && !ViewModel.IsBusy && !_dialogOpen;
        LibraryButton.IsEnabled = GalleryGrid.IsEnabled = !ViewModel.IsBusy && !_dialogOpen;
        NoMatchesPanel.Visibility = _didLoad && ViewModel.Gallery.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnShowLibrary(object sender, RoutedEventArgs e)
    {
        if (!ViewModel.IsBusy && !_dialogOpen) DesktopWindowManager.ShowLibrary("library");
    }

    private void OnAddButtonLoaded(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: DesktopGalleryItem item } button) return;
        button.Content = ViewModel.AddLabel;
        AutomationProperties.SetName(button, ViewModel.AddLabel + ": " + item.Title);
    }

    private async void OnAddTemplate(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DesktopGalleryItem item } || ViewModel.IsBusy || _dialogOpen) return;
        ViewModel.SelectedTemplate = item;
        await ViewModel.AddCommand.ExecuteAsync(item);
    }

    private async void OnGalleryKeyDown(object sender, KeyRoutedEventArgs e)
    {
        // A focused Add button handles Enter itself; only the selected tile uses this shortcut.
        if (e.OriginalSource is Button || e.Key != VirtualKey.Enter || ViewModel.IsBusy || _dialogOpen
            || ViewModel.SelectedTemplate is not { } item) return;
        e.Handled = true;
        await ViewModel.AddCommand.ExecuteAsync(item);
    }

    private void OnItemContextRequested(UIElement sender, ContextRequestedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DesktopGalleryItem item } element) return;
        ShowItemContextMenu(element, item, e);
    }

    private void OnCollectionContextRequested(UIElement sender, ContextRequestedEventArgs e)
    {
        // Keyboard context requests originate at the native item container, outside its template.
        if (e.TryGetPosition(sender, out _) || sender is not ListViewBase list
            || list.SelectedItem is not DesktopGalleryItem item
            || list.ContainerFromItem(item) is not FrameworkElement container) return;
        ShowItemContextMenu(container, item, e);
    }

    private void ShowItemContextMenu(FrameworkElement element, DesktopGalleryItem item, ContextRequestedEventArgs e)
    {
        if (ViewModel.IsBusy || _dialogOpen) return;
        ViewModel.SelectedTemplate = item;
        var menu = new MenuFlyout();
        var presenter = new Style(typeof(MenuFlyoutPresenter));
        presenter.Setters.Add(new Setter(FrameworkElement.FlowDirectionProperty, FlowDirection));
        menu.MenuFlyoutPresenterStyle = presenter;
        menu.Items.Add(new MenuFlyoutItem { Text = ViewModel.AddLabel, Command = ViewModel.AddCommand, CommandParameter = item });
        if (e.TryGetPosition(element, out var point)) menu.ShowAt(element, point);
        else menu.ShowAt(element);
        e.Handled = true;
    }

    private async Task ShowErrorAsync(string message)
    {
        if (!_isActive || _dialogOpen) return;
        _dialogOpen = true;
        UpdateActions();
        try
        {
            await new ContentDialog
            {
                XamlRoot = XamlRoot, FlowDirection = FlowDirection, Title = ViewModel.GalleryTitle,
                Content = message, CloseButtonText = Loc.Tr("common_ok", "OK"),
                DefaultButton = ContentDialogButton.Close
            }.ShowAsync();
        }
        finally { _dialogOpen = false; UpdateActions(); }
    }

    private void OnArtworkFailed(object sender, ExceptionRoutedEventArgs e)
    {
        if (sender is Image image && (image.Source is not BitmapImage current || current.UriSource != PlaceholderArtwork))
            image.Source = new BitmapImage(PlaceholderArtwork);
    }
}
