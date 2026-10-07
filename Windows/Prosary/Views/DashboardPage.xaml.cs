using System.ComponentModel;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.ViewModels;
using Windows.Storage;

namespace Prosary.Views;

public sealed partial class DashboardPage : Page
{
    public DashboardViewModel ViewModel { get; }
    public FlowDirection ContentDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    private readonly DispatcherQueueTimer _clock;
    private bool _dialogOpen;
    private bool _photoBusy;
    private TextBlock? _customizationError;
    private (string Title, string Message)? _pendingError;

    public DashboardPage()
    {
        ViewModel = new(App.Services.GetRequiredService<IPresetStore>());
        InitializeComponent();
        NavigationCacheMode = NavigationCacheMode.Required;
        _clock = DispatcherQueue.CreateTimer();
        _clock.Interval = TimeSpan.FromMinutes(1);
        _clock.Tick += (_, _) => RefreshToday();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.Navigation = Router.For(this);
        ViewModel.Today = ViewModel.Navigation.Today;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        AppSettings.HomeWidgetsChanged += OnLayoutChanged;
        DesktopLibraryChanges.Changed += OnLibraryChanged;
        if (ViewModel.Today is { } today) today.PropertyChanged += OnTodayChanged;
        ViewModel.ReloadLayout();
        RefreshToday();
        await RefreshRemindersAsync();
        if (IsLoaded) _clock.Start();
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        _clock.Stop();
        AppSettings.HomeWidgetsChanged -= OnLayoutChanged;
        DesktopLibraryChanges.Changed -= OnLibraryChanged;
        if (ViewModel.Today is { } today) today.PropertyChanged -= OnTodayChanged;
    }

    private void OnLayoutChanged() => DispatcherQueue.TryEnqueue(async () =>
    {
        if (!IsLoaded) return;
        ViewModel.ReloadLayout();
        await RefreshRemindersAsync();
    });

    private void OnLibraryChanged() => DispatcherQueue.TryEnqueue(async () =>
    {
        if (IsLoaded) await RefreshRemindersAsync();
    });

    private void OnTodayChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(HomeViewModel.SelectedTodayDate)) ViewModel.RefreshToday();
    }

    private void RefreshToday()
    {
        ViewModel.Today?.RefreshForClock(DateOnly.FromDateTime(DateTime.Today));
        ViewModel.RefreshToday();
    }

    private async Task RefreshRemindersAsync()
    {
        try { await ViewModel.RefreshRemindersAsync(); }
        catch (Exception error) { if (IsLoaded) await ShowErrorAsync(Loc.Tr("home_widgets_reminders", "Reminders"), error.Message); }
    }

    private void OnAddWidget(object sender, RoutedEventArgs e)
    { if (sender is FrameworkElement { DataContext: HomeWidgetCard card }) ViewModel.AddCommand.Execute(card); }
    private async void OnRemoveWidget(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: HomeWidgetCard card }) return;
        if (card.Id == "photo" && _photoBusy) return;
        try
        {
            if (card.Id == "photo")
            {
                DeletePhoto(AppSettings.HomePhotoPath);
                AppSettings.SetHomePhotoPath("");
            }
            ViewModel.RemoveCommand.Execute(card);
        }
        catch (Exception error)
        {
            await ShowErrorAsync(Loc.Tr("home_widgets_photo_error", "Could Not Load Photo"), error.Message);
        }
    }
    private void OnMoveUp(object sender, RoutedEventArgs e)
    { if (sender is FrameworkElement { DataContext: HomeWidgetCard card }) ViewModel.MoveUpCommand.Execute(card); }
    private void OnMoveDown(object sender, RoutedEventArgs e)
    { if (sender is FrameworkElement { DataContext: HomeWidgetCard card }) ViewModel.MoveDownCommand.Execute(card); }
    private void OnEditReminder(object sender, RoutedEventArgs e)
    { if (sender is FrameworkElement { DataContext: HomeReminderRow row }) ViewModel.EditReminderCommand.Execute(row); }

    private async void OnCardAction(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: HomeWidgetCard card }) return;
        if (card.Id != "reminders") { ViewModel.OpenCommand.Execute(card); return; }
        if (_dialogOpen) return;
        _dialogOpen = true;
        var owner = Router.For(this).OwnerWindow;
        try
        {
            var prayers = await App.Services.GetRequiredService<IPresetStore>().GetAllAsync();
            if (Router.For(this).OwnerWindow != owner || !IsLoaded) return;
            var list = new ListView { ItemsSource = prayers, DisplayMemberPath = "DisplayName", SelectionMode = ListViewSelectionMode.Single,
                MaxHeight = 420 };
            if (prayers.Count > 0) list.SelectedIndex = 0;
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot, Title = card.ActionTitle, FlowDirection = ContentDirection,
                Content = prayers.Count > 0 ? list : new TextBlock { Text = Loc.Tr("home_widgets_no_reminders", "No reminders yet."), TextWrapping = TextWrapping.Wrap },
                PrimaryButtonText = prayers.Count > 0 ? Loc.Tr("desktop_open", "Open") : "",
                SecondaryButtonText = Loc.Tr("SetTitle/Text", "Settings"),
                CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            };
            var result = await dialog.ShowAsync();
            if (Router.For(this).OwnerWindow != owner || !IsLoaded) return;
            if (result == ContentDialogResult.Primary && list.SelectedItem is Prayer prayer)
                ViewModel.Navigation.Navigate<RemindersOnlyEditorPage>(prayer.Id);
            else if (result == ContentDialogResult.Secondary) ViewModel.Navigation.Navigate<SettingsPage>();
        }
        catch (Exception error) { if (IsLoaded) await ShowErrorAsync(card.Title, error.Message); }
        finally { await CloseDialogAsync(); }
    }

    private async void OnCustomize(object sender, RoutedEventArgs e)
    {
        if (_dialogOpen || _photoBusy) return;
        _dialogOpen = true;
        try
        {
            var selected = new ListView
            {
                ItemsSource = ViewModel.Cards, ItemTemplate = (DataTemplate)Resources["SelectedWidgetTemplate"],
                CanReorderItems = true, CanDragItems = true, AllowDrop = true,
                SelectionMode = ListViewSelectionMode.None, MaxHeight = 360,
            };
            selected.DragItemsCompleted += (_, _) => ViewModel.SaveOrder();
            var content = new StackPanel { Spacing = 12, MinWidth = 320, FlowDirection = ContentDirection };
            _customizationError = new TextBlock { TextWrapping = TextWrapping.Wrap, Visibility = Visibility.Collapsed };
            content.Children.Add(_customizationError);
            content.Children.Add(new TextBlock { Text = ViewModel.SelectedLabel, FontWeight = Windows.UI.Text.FontWeights.SemiBold });
            content.Children.Add(selected);
            content.Children.Add(new TextBlock { Text = ViewModel.AvailableLabel, FontWeight = Windows.UI.Text.FontWeights.SemiBold });
            content.Children.Add(new ItemsControl { ItemsSource = ViewModel.AvailableCards, ItemTemplate = (DataTemplate)Resources["AvailableWidgetTemplate"] });
            await new ContentDialog
            {
                XamlRoot = XamlRoot, Title = ViewModel.CustomizeLabel, FlowDirection = ContentDirection,
                Content = new ScrollViewer { Content = content, MaxHeight = 620, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled },
                CloseButtonText = Loc.Tr("common_done", "Done"),
            }.ShowAsync();
        }
        catch (Exception error) { _pendingError = (ViewModel.CustomizeLabel, error.Message); }
        finally { _customizationError = null; await CloseDialogAsync(); }
    }

    private static bool IsOwnedPhoto(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return false;
        var directory = Path.Combine(ApplicationData.Current.LocalFolder.Path, "HomePhotos");
        return string.Equals(Path.GetDirectoryName(Path.GetFullPath(path)), directory, StringComparison.OrdinalIgnoreCase);
    }

    private static void DeletePhoto(string path)
    { if (IsOwnedPhoto(path) && File.Exists(path)) File.Delete(path); }

    private async void OnChoosePhoto(object sender, RoutedEventArgs e)
    {
        if (_dialogOpen || _photoBusy) return;
        var owner = Router.For(this).OwnerWindow;
        if (owner is null) return;
        _photoBusy = true;
        string? newPath = null;
        try
        {
            var picker = new Windows.Storage.Pickers.FileOpenPicker { SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.PicturesLibrary };
            WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(owner));
            foreach (var extension in new[] { ".jpg", ".jpeg", ".png", ".webp", ".bmp" }) picker.FileTypeFilter.Add(extension);
            if (await picker.PickSingleFileAsync() is not { } file) return;
            if (Router.For(this).OwnerWindow != owner || !IsLoaded) return;
            var folder = await ApplicationData.Current.LocalFolder.CreateFolderAsync("HomePhotos", CreationCollisionOption.OpenIfExists);
            var copy = await file.CopyAsync(folder, Guid.NewGuid().ToString("N") + Path.GetExtension(file.Name), NameCollisionOption.FailIfExists);
            newPath = copy.Path;
            if (Router.For(this).OwnerWindow != owner || !IsLoaded) { DeletePhoto(newPath); return; }
            // Keep the last valid photo until WinUI has decoded this candidate successfully.
            var bitmap = new Microsoft.UI.Xaml.Media.Imaging.BitmapImage();
            using (var stream = await copy.OpenReadAsync()) await bitmap.SetSourceAsync(stream);
            if (Router.For(this).OwnerWindow != owner || !IsLoaded) { DeletePhoto(newPath); return; }
            var previous = AppSettings.HomePhotoPath;
            AppSettings.SetHomePhotoPath(newPath);
            newPath = null;
            DeletePhoto(previous);
        }
        catch (Exception error)
        {
            if (newPath is not null)
            {
                try { DeletePhoto(newPath); }
                catch (Exception cleanupError) { error = new AggregateException(error, cleanupError); }
            }
            if (Router.For(this).OwnerWindow == owner && IsLoaded)
                await ShowErrorAsync(Loc.Tr("home_widgets_photo_error", "Could Not Load Photo"), error.Message);
        }
        finally { _photoBusy = false; }
    }

    private async void OnRemovePhoto(object sender, RoutedEventArgs e)
    {
        if (_photoBusy) return;
        try { var previous = AppSettings.HomePhotoPath; DeletePhoto(previous); AppSettings.SetHomePhotoPath(""); }
        catch (Exception error) { await ShowErrorAsync(Loc.Tr("home_widgets_photo_error", "Could Not Load Photo"), error.Message); }
    }

    private void OnPhotoFailed(object sender, ExceptionRoutedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: HomeWidgetCard card })
        {
            card.PhotoSource = null;
            card.Body = Loc.Tr("home_widgets_photo_error", "Could Not Load Photo");
        }
    }

    private async Task ShowErrorAsync(string title, string message)
    {
        if (XamlRoot is null || !IsLoaded) return;
        if (_customizationError is { } inlineError)
        {
            inlineError.Text = title + Environment.NewLine + message;
            inlineError.Visibility = Visibility.Visible;
            return;
        }
        if (_dialogOpen) { _pendingError = (title, message); return; }
        _dialogOpen = true;
        try
        {
            await new ContentDialog { XamlRoot = XamlRoot, Title = title, Content = message, FlowDirection = ContentDirection,
                CloseButtonText = Loc.Tr("common_ok", "OK") }.ShowAsync();
        }
        finally { await CloseDialogAsync(); }
    }

    private async Task CloseDialogAsync()
    {
        _dialogOpen = false;
        var pending = _pendingError;
        _pendingError = null;
        if (pending is { } error && IsLoaded) await ShowErrorAsync(error.Title, error.Message);
    }
}
