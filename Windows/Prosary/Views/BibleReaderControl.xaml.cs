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
    private const string IntroductionBlockId = "\0introduction";
    private IReadOnlyList<BibleVerseRow> _bookRows = [];
    private IReadOnlyList<BibleBookPage> _pages = [];
    private ScrollViewer? _verseScroller;
    private string? _anchorBlockId;
    private string? _chapterKey;
    private int _spreadStart;
    private bool _bookMode;
    private bool _rebuildQueued;
    private bool _updatingSpread;
    private ScrollViewer? _activePageScroller;
    private Storyboard? _pageTurnTransition;
    private UISettings? _uiSettings;
    public BibleReaderControl()
    {
        InitializeComponent();
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
        AttachVerseScroller();
        QueueBookLayout();
    }
    private void OnUnloaded(object sender, RoutedEventArgs args)
    {
        StopBookTransition();
        ViewModel.ConfirmRemoval = null;
        ViewModel.VerseRequested -= OnVerseRequested;
        ViewModel.PropertyChanged -= OnReaderPropertyChanged;
        if (_verseScroller is not null) _verseScroller.ViewChanged -= OnVerseScrollChanged;
        _verseScroller = null;
        AppSettings.ReadingsEditionChanged -= OnEditionChanged;
        AppSettings.TypographyChanged -= OnTypographyChanged;
        BibleLibraryStore.Default.Changed -= OnLibraryChanged;
        ViewModel.StopLoading();
    }
    private void OnVerseRequested(BibleVerseRow verse)
    {
        _chapterKey = CurrentChapterKey;
        _anchorBlockId = verse.Id;
        if (_bookMode) QueueBookLayout();
        else DispatcherQueue.TryEnqueue(() => { if (IsLoaded) VerseList.ScrollIntoView(verse, ScrollIntoViewAlignment.Leading); });
    }

    private void OnBibleTextViewportSizeChanged(object sender, SizeChangedEventArgs args)
    {
        CaptureScrollAnchor();
        QueueBookLayout();
    }

    private void OnReaderPropertyChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(BibleViewModel.Verses) or nameof(BibleViewModel.Introduction)
            or nameof(BibleViewModel.BodyFontFamily) or nameof(BibleViewModel.BodyFontSize)
            or nameof(BibleViewModel.IsRightToLeft) or nameof(BibleViewModel.IsInstalled)
            or nameof(BibleViewModel.IsLoading)) QueueBookLayout();
    }

    private void QueueBookLayout()
    {
        if (_rebuildQueued || !IsLoaded) return;
        _rebuildQueued = true;
        DispatcherQueue.TryEnqueue(() =>
        {
            _rebuildQueued = false;
            if (IsLoaded) RebuildBookLayout();
        });
    }

    private void RebuildBookLayout()
    {
        StopBookTransition();
        var chapterKey = CurrentChapterKey;
        if (_chapterKey != chapterKey)
        {
            _chapterKey = chapterKey;
            _anchorBlockId = ViewModel.HasIntroduction ? IntroductionBlockId : ViewModel.Verses.FirstOrDefault()?.Id;
        }
        var rows = new List<BibleVerseRow>();
        if (ViewModel.HasIntroduction) rows.Add(new(0, ViewModel.Introduction, Id: IntroductionBlockId, Kind: "passage"));
        rows.AddRange(ViewModel.Verses);
        _bookRows = rows;
        var facing = ViewModel.IsInstalled && rows.Count > 0
            && BibleBookPagination.SupportsFacingPages(BibleTextViewport.ActualWidth, BibleTextViewport.ActualHeight);
        var wasBookMode = _bookMode;
        _bookMode = facing;
        VerseList.Visibility = facing ? Visibility.Collapsed : Visibility.Visible;
        BookReader.Visibility = facing ? Visibility.Visible : Visibility.Collapsed;
        if (!facing)
        {
            if (wasBookMode) DispatcherQueue.TryEnqueue(RestoreScrollAnchor);
            return;
        }
        BookReader.Clip = new RectangleGeometry { Rect = new Rect(0, 0,
            Math.Max(0, BibleTextViewport.ActualWidth), Math.Max(0, BibleTextViewport.ActualHeight)) };

        var scriptureDirection = ViewModel.IsRightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        FacingPageSpread.FlowDirection = scriptureDirection;
        BookPageNavigation.FlowDirection = scriptureDirection;
        BookPageCount.FlowDirection = FlowDirection; // Count wording belongs to the interface.
        var family = new FontFamily(ViewModel.BodyFontFamily);
        foreach (var panel in new[] { FirstPageBlocks, SecondPageBlocks })
        {
            panel.FontFamily = family;
            panel.FontSize = ViewModel.BodyFontSize;
            panel.FlowDirection = scriptureDirection;
        }
        var pageWidth = Math.Max(1, (BibleTextViewport.ActualWidth - 24) / 2 - 16);
        // Reserve the native 48-point turn controls and the 12-point gap below each spread.
        var pageHeight = Math.Max(1, BibleTextViewport.ActualHeight - 60);
        var heights = rows.Select(row => MeasureBlock(row, pageWidth, family, scriptureDirection)).ToList();
        _pages = BibleBookPagination.Paginate(heights, pageHeight);
        var anchor = rows.FindIndex(row => row.Id == _anchorBlockId);
        _spreadStart = BibleBookPagination.SpreadContaining(_pages, Math.Max(0, anchor));
        ShowSpread();
    }

    private string CurrentChapterKey => $"{ViewModel.EffectiveEdition?.Id}|{ViewModel.SelectedBook?.Book.Id}|{ViewModel.SelectedChapter?.Chapter.Number}";

    private double MeasureBlock(BibleVerseRow row, double width, FontFamily family, FlowDirection direction)
    {
        var block = new ContentControl { Content = row, ContentTemplate = (DataTemplate)Resources["BibleBookBlockTemplate"],
            Width = width, FontFamily = family, FontSize = ViewModel.BodyFontSize, FlowDirection = direction,
            Padding = new Thickness(0), IsEnabled = false, HorizontalContentAlignment = HorizontalAlignment.Stretch };
        BookMeasurementHost.Children.Add(block);
        block.Measure(new Size(width, double.PositiveInfinity));
        ApplyBookTypography(block, row);
        block.Measure(new Size(width, double.PositiveInfinity));
        var height = Math.Max(1, block.DesiredSize.Height);
        BookMeasurementHost.Children.Remove(block);
        return height;
    }

    private void OnBookBlockLoaded(object sender, RoutedEventArgs args)
    {
        if (sender is ContentControl { Content: BibleVerseRow row } block) ApplyBookTypography(block, row);
    }

    private static void ApplyBookTypography(DependencyObject root, BibleVerseRow row)
    {
        if (root is TextBlock { Name: "BibleScriptureText" } scripture)
        {
            scripture.TextAlignment = TextAlignment.Justify;
            var label = row.Kind switch
            {
                "verse" when !row.UsesPrintedLabels => "\u2066" + row.VerseLabel + "\u2069",
                "witness" => "\u2068" + row.PrintedLabel + "\u2069",
                _ => null
            };
            // The source model owns every address and printed-label policy. Never infer a
            // marker from the numeric-looking start of a source passage.
            if (label is not null && label + "  " + row.Text == row.DisplayText)
            {
                var marker = new Run { Text = label, FontFamily = new FontFamily("Segoe UI"),
                    FontSize = scripture.FontSize * 0.8 };
                // Fonts with no superscript variant retain the smaller inline marker.
                Typography.SetVariants(marker, FontVariants.Superscript);
                scripture.Inlines.Clear();
                scripture.Inlines.Add(marker);
                scripture.Inlines.Add(new Run { Text = "  " + row.Text });
            }
        }
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); index++)
            ApplyBookTypography(VisualTreeHelper.GetChild(root, index), row);
    }

    private void ShowSpread()
    {
        if (!_bookMode || _pages.Count == 0) return;
        _updatingSpread = true;
        _activePageScroller = null;
        var first = _pages[_spreadStart];
        FirstPageBlocks.ItemsSource = _bookRows.Skip(first.Start).Take(first.Count).ToList();
        SecondPageBlocks.ItemsSource = _spreadStart + 1 < _pages.Count
            ? _bookRows.Skip(_pages[_spreadStart + 1].Start).Take(_pages[_spreadStart + 1].Count).ToList() : [];
        SecondPageScroll.Visibility = _spreadStart + 1 < _pages.Count ? Visibility.Visible : Visibility.Collapsed;
        FirstPageScroll.ChangeView(null, 0, null, true);
        SecondPageScroll.ChangeView(null, 0, null, true);
        PreviousPageButton.IsEnabled = _spreadStart > 0;
        NextPageButton.IsEnabled = _spreadStart + 2 < _pages.Count;
        PreviousPageIcon.Symbol = ViewModel.IsRightToLeft ? Symbol.Forward : Symbol.Back;
        NextPageIcon.Symbol = ViewModel.IsRightToLeft ? Symbol.Back : Symbol.Forward;
        var previous = Loc.Tr("bible_previous_page", "Previous Page");
        var next = Loc.Tr("bible_next_page", "Next Page");
        AutomationProperties.SetName(PreviousPageButton, previous);
        AutomationProperties.SetName(NextPageButton, next);
        ToolTipService.SetToolTip(PreviousPageButton, previous);
        ToolTipService.SetToolTip(NextPageButton, next);
        BookPageCount.Text = string.Format(Loc.Tr("bible_page_count", "Pages {0}–{1} of {2}"),
            _spreadStart + 1, Math.Min(_spreadStart + 2, _pages.Count), _pages.Count);
        AutomationProperties.SetName(FirstPageScroll, string.Format(Loc.Tr("bible_page_count", "Pages {0}–{1} of {2}"),
            _spreadStart + 1, _spreadStart + 1, _pages.Count));
        if (_spreadStart + 1 < _pages.Count)
            AutomationProperties.SetName(SecondPageScroll, string.Format(Loc.Tr("bible_page_count", "Pages {0}–{1} of {2}"),
                _spreadStart + 2, _spreadStart + 2, _pages.Count));
        DispatcherQueue.TryEnqueue(() => _updatingSpread = false);
    }

    private bool TurnSpread(int direction)
    {
        var next = _spreadStart + direction * 2;
        if (!_bookMode || direction is not (-1 or 1) || next < 0 || next >= _pages.Count) return false;
        _spreadStart = next;
        _anchorBlockId = _bookRows[_pages[next].Start].Id;
        ShowSpread();
        AnimateBookTurn(direction);
        return true;
    }

    private void AnimateBookTurn(int direction)
    {
        StopBookTransition();
        if (!(_uiSettings ??= new UISettings()).AnimationsEnabled) return;
        // Native Windows motion enters from Scripture's inline end for a forward turn.
        // Page content and its source anchor change together before this visual transition.
        var offset = direction * (ViewModel.IsRightToLeft ? -1 : 1)
            * Math.Min(60, FacingPageSpread.ActualWidth * 0.08);
        var translation = new TranslateTransform();
        FacingPageSpread.RenderTransform = translation;
        var movement = new DoubleAnimation { From = offset, To = 0,
            Duration = new Duration(TimeSpan.FromMilliseconds(220)),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } };
        Storyboard.SetTarget(movement, translation);
        Storyboard.SetTargetProperty(movement, nameof(TranslateTransform.X));
        var transition = new Storyboard();
        transition.Children.Add(movement);
        _pageTurnTransition = transition;
        transition.Begin();
    }

    private void StopBookTransition()
    {
        _pageTurnTransition?.Stop();
        _pageTurnTransition = null;
        if (FacingPageSpread.RenderTransform is TranslateTransform translation) translation.X = 0;
    }

    private void OnPreviousPage(object sender, RoutedEventArgs args) => TurnSpread(-1);
    private void OnNextPage(object sender, RoutedEventArgs args) => TurnSpread(1);
    private void OnBookManipulationCompleted(object sender, ManipulationCompletedRoutedEventArgs args) =>
        TurnSpread(BibleBookPagination.SwipeDirection(args.Cumulative.Translation.X, ViewModel.IsRightToLeft));
    private void OnBookPointerWheelChanged(object sender, PointerRoutedEventArgs args)
    {
        var properties = args.GetCurrentPoint(FacingPageSpread).Properties;
        if (!properties.IsHorizontalMouseWheel || properties.MouseWheelDelta == 0) return;
        var direction = properties.MouseWheelDelta > 0 ? 1 : -1;
        if (ViewModel.IsRightToLeft) direction = -direction;
        args.Handled = TurnSpread(direction);
    }

    private void OnBookPagePointerPressed(object sender, PointerRoutedEventArgs args)
    {
        _activePageScroller = sender as ScrollViewer;
        CaptureBookPageAnchor(sender);
    }
    private void OnBookPagePointerWheelChanged(object sender, PointerRoutedEventArgs args)
    {
        if (!args.GetCurrentPoint(FacingPageSpread).Properties.IsHorizontalMouseWheel)
            _activePageScroller = sender as ScrollViewer;
    }
    private void OnBookPageViewChanged(object? sender, ScrollViewerViewChangedEventArgs args)
    {
        if (!args.IsIntermediate && !_updatingSpread && ReferenceEquals(sender, _activePageScroller)) CaptureBookPageAnchor(sender);
    }

    private void CaptureBookPageAnchor(object? sender)
    {
        if (!_bookMode || _pages.Count == 0 || sender is not ScrollViewer scroller) return;
        var pageIndex = _spreadStart + (ReferenceEquals(scroller, SecondPageScroll) ? 1 : 0);
        if (pageIndex >= _pages.Count) return;
        var items = ReferenceEquals(scroller, SecondPageScroll) ? SecondPageBlocks : FirstPageBlocks;
        var page = _pages[pageIndex];
        for (var index = 0; index < page.Count; index++)
        {
            if (items.ContainerFromIndex(index) is not FrameworkElement block) continue;
            var top = block.TransformToVisual(scroller).TransformPoint(new Point(0, 0)).Y;
            if (top + block.ActualHeight <= 0) continue;
            _anchorBlockId = _bookRows[page.Start + index].Id;
            return;
        }
        _anchorBlockId = _bookRows[page.Start].Id;
    }

    private void AttachVerseScroller()
    {
        _verseScroller ??= Descendant<ScrollViewer>(VerseList);
        if (_verseScroller is not null)
        {
            _verseScroller.ViewChanged -= OnVerseScrollChanged;
            _verseScroller.ViewChanged += OnVerseScrollChanged;
        }
    }

    private void OnVerseScrollChanged(object? sender, ScrollViewerViewChangedEventArgs args)
    {
        if (!args.IsIntermediate) CaptureScrollAnchor();
    }

    private void CaptureScrollAnchor()
    {
        if (_bookMode || VerseList.Visibility != Visibility.Visible) return;
        AttachVerseScroller();
        if (ViewModel.HasIntroduction && _verseScroller?.VerticalOffset <= 0)
        {
            _anchorBlockId = IntroductionBlockId;
            return;
        }
        for (var index = 0; index < ViewModel.Verses.Count; index++)
        {
            if (VerseList.ContainerFromIndex(index) is not FrameworkElement block) continue;
            var top = block.TransformToVisual(VerseList).TransformPoint(new Point(0, 0)).Y;
            if (top + block.ActualHeight <= 0) continue;
            _anchorBlockId = ViewModel.Verses[index].Id;
            return;
        }
    }

    private void RestoreScrollAnchor()
    {
        if (!IsLoaded || _bookMode) return;
        AttachVerseScroller();
        if (_anchorBlockId == IntroductionBlockId) _verseScroller?.ChangeView(null, 0, null, true);
        else if (ViewModel.Verses.FirstOrDefault(row => row.Id == _anchorBlockId) is { } row)
            VerseList.ScrollIntoView(row, ScrollIntoViewAlignment.Leading);
    }

    private static T? Descendant<T>(DependencyObject root) where T : DependencyObject
    {
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); index++)
        {
            var child = VisualTreeHelper.GetChild(root, index);
            if (child is T found) return found;
            if (Descendant<T>(child) is { } nested) return nested;
        }
        return null;
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
