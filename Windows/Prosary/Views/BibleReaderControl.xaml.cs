using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Documents;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using System.ComponentModel;
using Windows.Foundation;
using Windows.UI.ViewManagement;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class BibleReaderControl : UserControl
{
    public BibleViewModel ViewModel { get; } = new();
    private bool _dialogOpen;
    private bool? _compactPassageSelectors;
    public BibleReaderControl()
    {
        InitializeComponent();
        EditionReader.ChromeChanged += hidden =>
        {
            BibleOptionsScroll.Visibility = hidden ? Visibility.Collapsed : Visibility.Visible;
            if (App.MainWindow is MainWindow window && window.Content.XamlRoot == XamlRoot)
                window.SetBibleReadingFocus(hidden);
        };
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }
    private void OnBibleLayoutSizeChanged(object sender, SizeChangedEventArgs args)
    {
        // Keep verse space available even when the selectors need a second row.
        var availableHeight = args.NewSize.Height - BibleLayout.Padding.Top
            - BibleLayout.Padding.Bottom - BibleLayout.RowSpacing;
        BibleOptionsScroll.MaxHeight = Math.Max(0, availableHeight * 0.5);
    }
    private void OnPassageSelectorsSizeChanged(object sender, SizeChangedEventArgs args)
    {
        // The page can be narrower than its window because of the library sidebar.
        var compact = args.NewSize.Width < 600;
        if (_compactPassageSelectors == compact) return;
        _compactPassageSelectors = compact;
        BookSelectorColumn.Width = new GridLength(compact ? 1 : 2, GridUnitType.Star);
        if (compact) PassageSelectors.ColumnDefinitions.Remove(VerseSelectorColumn);
        else if (!PassageSelectors.ColumnDefinitions.Contains(VerseSelectorColumn))
            PassageSelectors.ColumnDefinitions.Add(VerseSelectorColumn);
        PassageSelectors.RowSpacing = compact ? 12 : 0;
        Grid.SetColumnSpan(BookSelector, compact ? 2 : 1);
        Grid.SetRow(ChapterSelector, compact ? 1 : 0);
        Grid.SetColumn(ChapterSelector, compact ? 0 : 1);
        Grid.SetRow(VerseSelector, compact ? 1 : 0);
        Grid.SetColumn(VerseSelector, compact ? 1 : 2);
    }
    private async void OnLoaded(object sender, RoutedEventArgs args)
    {
        ViewModel.ConfirmRemoval = ConfirmRemovalAsync;
        ViewModel.VerseRequested += OnVerseRequested;
        ViewModel.PropertyChanged += OnReaderPropertyChanged;
        AppSettings.ReadingsEditionChanged += OnEditionChanged;
        AppSettings.TypographyChanged += OnTypographyChanged;
        BibleLibraryStore.Default.Changed += OnLibraryChanged;
        await ViewModel.RefreshAsync();
        if (!IsLoaded) return;
        await EditionReader.ConfigureAsync(ViewModel);
    }
    private void OnUnloaded(object sender, RoutedEventArgs args)
    {
        EditionReader.RestoreChrome();
        ViewModel.ConfirmRemoval = null;
        ViewModel.VerseRequested -= OnVerseRequested;
        ViewModel.PropertyChanged -= OnReaderPropertyChanged;
        AppSettings.ReadingsEditionChanged -= OnEditionChanged;
        AppSettings.TypographyChanged -= OnTypographyChanged;
        BibleLibraryStore.Default.Changed -= OnLibraryChanged;
        ViewModel.StopLoading();
    }
    private void OnVerseRequested(BibleVerseRow verse)
    {
        if (ViewModel.SelectedBook is { } book && ViewModel.SelectedChapter is { } chapter)
            EditionReader.Jump($"{book.Book.Id}/{chapter.Chapter.Number}/{verse.Id}");
    }
    private async void OnReaderPropertyChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(BibleViewModel.ReaderSections) or nameof(BibleViewModel.BodyFontFamily)
            or nameof(BibleViewModel.BodyFontSize) or nameof(BibleViewModel.EffectiveScript))
            await EditionReader.ConfigureAsync(ViewModel);
    }

    private void OnEditionChanged() => DispatcherQueue.TryEnqueue(async () => { if (IsLoaded) await ViewModel.RefreshAsync(); });
    private void OnTypographyChanged() => DispatcherQueue.TryEnqueue(() => { if (IsLoaded) ViewModel.RefreshTypography(); });
    private void OnLibraryChanged(string id) => DispatcherQueue.TryEnqueue(async () =>
    {
        if (IsLoaded && ViewModel.EffectiveEdition?.Id == id && !ViewModel.IsDownloading) await ViewModel.RefreshAsync();
    });
    private async Task<bool> ConfirmRemovalAsync()
    {
        if (_dialogOpen || XamlRoot is null) return false;
        _dialogOpen = true;
        try
        {
            var dialog = new ContentDialog { XamlRoot = XamlRoot, FlowDirection = FlowDirection,
                Title = ViewModel.RemoveLabel,
                Content = string.Format(Loc.Tr("bible_remove_confirmation", "Remove the downloaded {0}? Daily readings remain available."), ViewModel.EditionName),
                PrimaryButtonText = ViewModel.RemoveLabel, CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
                DefaultButton = ContentDialogButton.Close };
            return await dialog.ShowAsync() == ContentDialogResult.Primary;
        }
        finally { _dialogOpen = false; }
    }
}
