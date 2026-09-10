using System.ComponentModel;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
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

public sealed partial class DesktopLibraryPage : Page
{
    public DesktopLibraryViewModel ViewModel { get; }
    private bool _isActive;
    private bool _dialogOpen;
    private bool _reloadPending;
    private static readonly Uri PlaceholderArtwork = new("ms-appx:///Assets/Images/cross_placeholder.png");

    public DesktopLibraryPage()
    {
        ViewModel = App.Services.GetRequiredService<DesktopLibraryViewModel>();
        InitializeComponent();
        FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        SetViewLabel(ListModeButton, Loc.Tr("desktop_list_view", "List View"));
        SetViewLabel(GridModeButton, Loc.Tr("desktop_grid_view", "Grid View"));
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        UpdateActions();
    }

    private static void SetViewLabel(FrameworkElement button, string label)
    {
        AutomationProperties.SetName(button, label);
        ToolTipService.SetToolTip(button, label);
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (_isActive) return;
        _isActive = true;
        ViewModel.Navigation = Router.For(this);
        ViewModel.ShowError = ShowErrorAsync;
        ViewModel.ConfirmDelete = ConfirmDeleteAsync;
        ViewModel.PropertyChanged += OnViewModelChanged;
        DesktopLibraryChanges.Changed += OnLibraryChanged;
        await ViewModel.LoadAsync();
        UpdateActions();
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        _isActive = false;
        _reloadPending = false;
        DesktopLibraryChanges.Changed -= OnLibraryChanged;
        ViewModel.PropertyChanged -= OnViewModelChanged;
        ViewModel.ShowError = null;
        ViewModel.ConfirmDelete = null;
    }

    private void OnLibraryChanged() => DispatcherQueue.TryEnqueue(async () =>
    {
        if (!_isActive) return;
        // Mutations refresh their own list and choose the new copy before external refreshes.
        if (ViewModel.IsBusy) { _reloadPending = true; return; }
        _reloadPending = false;
        await ViewModel.LoadAsync();
    });

    private void OnViewModelChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ViewModel.IsBusy) && !ViewModel.IsBusy && _reloadPending)
            OnLibraryChanged();
        if (e.PropertyName is nameof(ViewModel.SelectedItem) or nameof(ViewModel.IsBusy)) UpdateActions();
    }

    private void UpdateActions()
    {
        var canAct = ViewModel.SelectedItem is not null && !ViewModel.IsBusy && !_dialogOpen;
        OpenButton.IsEnabled = SettingsButton.IsEnabled = DuplicateButton.IsEnabled = RenameButton.IsEnabled = DeleteButton.IsEnabled = canAct;
        GalleryButton.IsEnabled = !ViewModel.IsBusy && !_dialogOpen;
    }

    private void OnShowGallery(object sender, RoutedEventArgs e)
    {
        if (!ViewModel.IsBusy && !_dialogOpen) DesktopWindowManager.ShowLibrary("gallery");
    }

    private void OnListMode(object sender, RoutedEventArgs e) => SetGridMode(false);
    private void OnGridMode(object sender, RoutedEventArgs e) => SetGridMode(true);
    private void SetGridMode(bool grid)
    {
        var selected = ViewModel.SelectedItem;
        PrayerList.Visibility = grid ? Visibility.Collapsed : Visibility.Visible;
        PrayerGrid.Visibility = grid ? Visibility.Visible : Visibility.Collapsed;
        ListModeButton.IsChecked = !grid;
        GridModeButton.IsChecked = grid;
        var target = grid ? (ListViewBase)PrayerGrid : PrayerList;
        if (selected is not null) target.ScrollIntoView(selected);
        target.Focus(FocusState.Programmatic);
    }

    private async void OnItemDoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DesktopPrayerItem item } || _dialogOpen) return;
        ViewModel.SelectedItem = item;
        e.Handled = true;
        await ViewModel.OpenCommand.ExecuteAsync(item);
    }

    private async void OnItemsKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (ViewModel.SelectedItem is not { } item || ViewModel.IsBusy || _dialogOpen) return;
        switch (e.Key)
        {
            case VirtualKey.Enter:
                e.Handled = true;
                await ViewModel.OpenCommand.ExecuteAsync(item);
                break;
            case VirtualKey.F2:
                e.Handled = true;
                await RenameAsync(item);
                break;
            case VirtualKey.Delete:
                e.Handled = true;
                await ViewModel.DeleteCommand.ExecuteAsync(item);
                break;
        }
    }

    private void OnItemContextRequested(UIElement sender, ContextRequestedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: DesktopPrayerItem item } element) return;
        ShowItemContextMenu(element, item, e);
    }

    private void OnCollectionContextRequested(UIElement sender, ContextRequestedEventArgs e)
    {
        // Keyboard context requests originate at the native item container, outside its template.
        if (e.TryGetPosition(sender, out _) || sender is not ListViewBase list
            || list.SelectedItem is not DesktopPrayerItem item
            || list.ContainerFromItem(item) is not FrameworkElement container) return;
        ShowItemContextMenu(container, item, e);
    }

    private void ShowItemContextMenu(FrameworkElement element, DesktopPrayerItem item, ContextRequestedEventArgs e)
    {
        if (ViewModel.IsBusy || _dialogOpen) return;
        // The clicked row is the command target, even when another row was selected.
        ViewModel.SelectedItem = item;
        var menu = new MenuFlyout();
        var presenter = new Style(typeof(MenuFlyoutPresenter));
        presenter.Setters.Add(new Setter(FrameworkElement.FlowDirectionProperty, FlowDirection));
        menu.MenuFlyoutPresenterStyle = presenter;
        menu.Items.Add(new MenuFlyoutItem { Text = ViewModel.OpenLabel, Command = ViewModel.OpenCommand, CommandParameter = item });
        menu.Items.Add(new MenuFlyoutItem { Text = ViewModel.SettingsLabel, Command = ViewModel.EditCommand, CommandParameter = item });
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(new MenuFlyoutItem { Text = ViewModel.DuplicateLabel, Command = ViewModel.DuplicateCommand, CommandParameter = item });
        var rename = new MenuFlyoutItem { Text = ViewModel.RenameLabel };
        rename.Click += async (_, _) => await RenameAsync(item);
        menu.Items.Add(rename);
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(new MenuFlyoutItem { Text = ViewModel.DeleteLabel, Command = ViewModel.DeleteCommand, CommandParameter = item });
        if (e.TryGetPosition(element, out var point)) menu.ShowAt(element, point);
        else menu.ShowAt(element);
        e.Handled = true;
    }

    private async void OnRename(object sender, RoutedEventArgs e)
    {
        if (ViewModel.SelectedItem is { } item) await RenameAsync(item);
    }

    private async Task RenameAsync(DesktopPrayerItem item)
    {
        if (!_isActive || ViewModel.IsBusy || _dialogOpen) return;
        _dialogOpen = true;
        UpdateActions();
        string? name = null;
        try
        {
            var label = Loc.Tr("desktop_name", "Name");
            var nameBox = new TextBox { Text = item.Prayer.Name, Header = label, MinWidth = 280 };
            AutomationProperties.SetName(nameBox, label);
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot, FlowDirection = FlowDirection, Title = ViewModel.RenameLabel,
                Content = nameBox, PrimaryButtonText = Loc.Tr("common_save", "Save"),
                CloseButtonText = Loc.Tr("common_cancel", "Cancel"), DefaultButton = ContentDialogButton.Primary,
                IsPrimaryButtonEnabled = !string.IsNullOrWhiteSpace(nameBox.Text)
            };
            nameBox.TextChanged += (_, _) => dialog.IsPrimaryButtonEnabled = !string.IsNullOrWhiteSpace(nameBox.Text);
            dialog.Opened += (_, _) => { nameBox.Focus(FocusState.Programmatic); nameBox.SelectAll(); };
            if (await dialog.ShowAsync() == ContentDialogResult.Primary) name = nameBox.Text.Trim();
        }
        finally { _dialogOpen = false; UpdateActions(); }
        if (!string.IsNullOrWhiteSpace(name) && _isActive) await ViewModel.RenameAsync(item, name);
    }

    private async Task<bool> ConfirmDeleteAsync(PrayerRemovalPlan plan)
    {
        if (!_isActive || _dialogOpen) return false;
        _dialogOpen = true;
        UpdateActions();
        try { return await PrayerRemovalDialogs.ConfirmDeleteAsync(XamlRoot, plan); }
        finally { _dialogOpen = false; UpdateActions(); }
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
                XamlRoot = XamlRoot, FlowDirection = FlowDirection, Content = message,
                Title = ViewModel.LibraryTitle, CloseButtonText = Loc.Tr("common_ok", "OK"),
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
