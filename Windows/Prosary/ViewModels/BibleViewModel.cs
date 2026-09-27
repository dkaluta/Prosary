using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record BibleBookChoice(BibleBook Book, string Label);
public sealed record BibleChapterChoice(BibleChapter Chapter, string Label);
public sealed record BibleVerseRow(int Verse, string Text, int? EndVerse = null)
{
    public string VerseLabel => EndVerse is { } end && end > Verse ? $"{Verse}–{end}" : Verse.ToString(System.Globalization.CultureInfo.InvariantCulture);
    public string DisplayText => $"\u2066{VerseLabel}\u2069  {Text}";
    public bool ContainsVerse(int number) => number >= Verse && number <= (EndVerse ?? Verse);
}
public sealed record BibleLocation(string Book, int Chapter);
public static class BibleNavigation
{
    public static BibleLocation? Adjacent(IReadOnlyList<BibleBook> books, BibleLocation current, int direction)
    {
        var locations = books.SelectMany(book => book.Chapters.Select(chapter => new BibleLocation(book.Id, chapter.Number))).ToList();
        var index = locations.IndexOf(current);
        var target = index + direction;
        return direction is -1 or 1 && index >= 0 && target >= 0 && target < locations.Count ? locations[target] : null;
    }
}

public partial class BibleViewModel : ObservableObject
{
    private readonly BibleLibraryStore _store;
    private bool _synchronizing;
    private int _request;
    private CancellationTokenSource? _chapterCancellation;
    private CancellationTokenSource? _downloadCancellation;
    private BibleManifest? _installed;
    private IReadOnlyList<ScriptureVerse> _sourceVerses = [];
    private int? _versePosition;
    private enum RetryOperation { Chapter, Download, Remove }
    private RetryOperation _retryOperation;
    public BibleViewModel(BibleLibraryStore? store = null) { _store = store ?? BibleLibraryStore.Default; SynchronizeEdition(); }
    public ObservableCollection<ReadingEditionChoice> Editions { get; } = [];
    public Func<Task<bool>>? ConfirmRemoval { get; set; }
    public event Action<BibleVerseRow>? VerseRequested;
    public string EditionLabel => Loc.Tr("readings_edition", "Bible Edition");
    public string BookLabel => Loc.Tr("bible_book", "Book");
    public string ChapterLabel => Loc.Tr("bible_chapter", "Chapter");
    public string VerseLabel => Loc.Tr("bible_verse", "Verse");
    public string PreviousLabel => Loc.Tr("bible_previous_chapter", "Previous chapter");
    public string NextLabel => Loc.Tr("bible_next_chapter", "Next chapter");
    public string DownloadLabel => UpdateAvailable ? Loc.Tr("bible_update", "Update download") : Loc.Tr("bible_download", "Download Bible");
    public string RemoveLabel => Loc.Tr("bible_remove", "Remove Download");
    public string CancelLabel => Loc.Tr("bible_cancel", "Cancel download");
    public string RetryLabel => Loc.Tr("bible_retry", "Retry");
    public string PartialNotice => Loc.Tr("bible_partial_chapter", "Only part of this chapter is available.");
    public string DownloadNotice => Loc.Tr("bible_download_notice", "Download this edition to read its available books offline. Daily readings work without this download.");
    public string UnavailableNotice => Loc.Tr("bible_unavailable", "No Bible download is available for the selected edition.");
    public string SourceLabel => Loc.Tr("readings_source", "Source and Edition");
    public string Attribution => SelectedBook?.Book.Attribution ?? EffectiveEdition?.Attribution ?? "";
    public Uri? SourceUri => Uri.TryCreate(SelectedBook?.Book.SourceURL ?? EffectiveEdition?.SourceURL, UriKind.Absolute, out var uri)
        && uri.Scheme is "https" or "http" ? uri : null;
    public bool HasSource => SourceUri is not null;
    public BibleEdition? EffectiveEdition => string.IsNullOrEmpty(SelectedEdition?.Id)
        ? _store.Editions.FirstOrDefault(edition => ReadingsTextStore.NormalizeLanguage(edition.LanguageCode) == ReadingsTextStore.NormalizeLanguage(UiLanguageCatalog.Current))
        : _store.Editions.FirstOrDefault(edition => edition.Id == SelectedEdition.Id);
    public bool HasEdition => EffectiveEdition is not null;
    public bool IsUnavailable => !HasEdition;
    public string EditionName => EffectiveEdition?.Name ?? "";
    public string EffectiveScript => ScriptOverride ?? AppSettings.AramaicDefaultScript;
    public bool HasScriptToggle => EffectiveEdition?.Scripture.HasAramaicScripts == true;
    public string ScriptLabel => EffectiveScript == "Syrc" ? Loc.Tr("settings_script_hebrew", "Hebrew Script") : Loc.Tr("settings_script_syriac", "Syriac Script");
    public bool ShowDownload => HasEdition && (!IsInstalled || UpdateAvailable) && !IsDownloading;
    public bool ShowDownloadNotice => HasEdition && !IsInstalled;
    public bool ShowRemove => IsInstalled && !IsDownloading;
    public bool HasError => !string.IsNullOrEmpty(Error);
    public bool HasChapter => Verses.Count > 0;
    public string Introduction => SelectedChapter is { } chapter ? SelectedBook?.Book.IntroductionForChapter(chapter.Chapter.Number) ?? "" : "";
    public bool HasIntroduction => !string.IsNullOrEmpty(Introduction);
    public bool CanNavigate => IsInstalled && !IsLoading && !IsDownloading;
    private BibleLocation? Location => SelectedBook is { } book && SelectedChapter is { } chapter ? new(book.Book.Id, chapter.Chapter.Number) : null;
    public bool HasPrevious => Location is { } current && BibleNavigation.Adjacent(_installed?.Books ?? [], current, -1) is not null;
    public bool HasNext => Location is { } current && BibleNavigation.Adjacent(_installed?.Books ?? [], current, 1) is not null;
    private PrayerTypography.Script TextScript => PrayerTypography.ScriptOf(Introduction + string.Concat(Verses.Select(verse => verse.Text)));
    public bool IsRightToLeft => PrayerTypography.IsRightToLeft(TextScript);
    public string BodyFontFamily => PrayerTypography.ResolveBodyFontFamily(EffectiveEdition?.LanguageCode, true, TextScript);
    public double BodyFontSize => PrayerTypography.ResolveBodyFontSize(EffectiveEdition?.LanguageCode, true, TextScript);
    public string ChapterHeading => SelectedChapter is { } chapter ? ReadingChapterHeading.Label(EffectiveEdition?.LanguageCode ?? "en", EffectiveScript) + " \u2068"
        + ReadingChapterHeading.Number(chapter.Chapter.Number, EffectiveEdition?.LanguageCode ?? "en", EffectiveScript) + "\u2069" : "";

    [ObservableProperty] private ReadingEditionChoice? _selectedEdition;
    [ObservableProperty] private ObservableCollection<BibleBookChoice> _books = [];
    [ObservableProperty] private BibleBookChoice? _selectedBook;
    [ObservableProperty] private ObservableCollection<BibleChapterChoice> _chapters = [];
    [ObservableProperty] private BibleChapterChoice? _selectedChapter;
    [ObservableProperty] private ObservableCollection<BibleVerseRow> _verses = [];
    [ObservableProperty] private BibleVerseRow? _selectedVerse;
    [ObservableProperty] private string? _scriptOverride;
    [ObservableProperty] private bool _isInstalled;
    [ObservableProperty] private bool _updateAvailable;
    [ObservableProperty] private bool _isPartial;
    [ObservableProperty] private bool _isLoading;
    [ObservableProperty] private bool _isDownloading;
    [ObservableProperty] private double _downloadProgress;
    [ObservableProperty] private string? _error;
    partial void OnErrorChanged(string? value) => OnPropertyChanged(nameof(HasError));
    partial void OnIsDownloadingChanged(bool value) => NotifyDisplay();
    partial void OnIsLoadingChanged(bool value) => OnPropertyChanged(nameof(CanNavigate));
    partial void OnSelectedVerseChanged(BibleVerseRow? value)
    {
        if (value is null) return;
        _versePosition = value.Verse;
        VerseRequested?.Invoke(value);
    }
    partial void OnScriptOverrideChanged(string? value) { RefreshChoices(); RefreshText(); }
    partial void OnSelectedEditionChanged(ReadingEditionChoice? value)
    {
        if (_synchronizing || value is null) return;
        _versePosition = null;
        AppSettings.SetReadingsEditionId(value.Id);
        _ = RefreshAsync();
    }
    partial void OnSelectedBookChanged(BibleBookChoice? value)
    {
        if (_synchronizing) return;
        _versePosition = null;
        RefreshChapters();
        _ = LoadChapterAsync();
    }
    partial void OnSelectedChapterChanged(BibleChapterChoice? value)
    {
        if (_synchronizing) return;
        _versePosition = null;
        _ = LoadChapterAsync();
    }

    public void SynchronizeEdition()
    {
        _synchronizing = true;
        try
        {
            if (Editions.Count == 0)
            {
                Editions.Add(new("", Loc.Tr("readings_edition_automatic", "Follow Interface Language")));
                foreach (var edition in _store.Editions) Editions.Add(new(edition.Id, edition.Name));
            }
            var id = AppSettings.ReadingsEditionId;
            if (SelectedEdition?.Id != id) _versePosition = null;
            var choice = Editions.FirstOrDefault(edition => edition.Id == id);
            if (choice is null) { choice = new(id, UnavailableNotice); Editions.Add(choice); }
            SelectedEdition = choice;
        }
        finally { _synchronizing = false; }
        NotifyDisplay();
    }

    public async Task RefreshAsync()
    {
        var request = ++_request;
        _chapterCancellation?.Cancel();
        _sourceVerses = [];
        Verses = [];
        IsPartial = false;
        SynchronizeEdition();
        var edition = EffectiveEdition;
        var installed = edition is null ? null : await _store.InstalledAsync(edition.Id);
        if (request != _request) return;
        _installed = installed;
        IsInstalled = _installed is not null;
        UpdateAvailable = _installed is not null && _installed.Revision != edition?.Revision;
        RefreshChoices();
        NotifyDisplay();
        await LoadChapterAsync();
    }

    private void RefreshChoices()
    {
        var previous = SelectedBook?.Book.Id;
        _synchronizing = true;
        try
        {
            Books = new((_installed?.Books ?? []).Select(book => new BibleBookChoice(book,
                HasScriptToggle && EffectiveScript == "Syrc" ? book.TransliteratedName ?? book.Name : book.Name)));
            SelectedBook = Books.FirstOrDefault(book => book.Book.Id == previous) ?? Books.FirstOrDefault();
            RefreshChapters();
        }
        finally { _synchronizing = false; }
    }
    private void RefreshChapters()
    {
        var synchronizing = _synchronizing;
        _synchronizing = true;
        try
        {
            var previous = SelectedChapter?.Chapter.Number;
            Chapters = new((SelectedBook?.Book.Chapters ?? []).Select(chapter => new BibleChapterChoice(chapter,
                ReadingChapterHeading.Number(chapter.Number, EffectiveEdition?.LanguageCode ?? "en", EffectiveScript))));
            SelectedChapter = Chapters.FirstOrDefault(chapter => chapter.Chapter.Number == previous) ?? Chapters.FirstOrDefault();
        }
        finally { _synchronizing = synchronizing; }
        NotifyDisplay();
    }

    [RelayCommand]
    private async Task LoadChapterAsync()
    {
        _chapterCancellation?.Cancel();
        var cancellation = _chapterCancellation = new();
        var request = ++_request;
        _sourceVerses = [];
        Verses = [];
        IsPartial = false;
        Error = null;
        if (!IsInstalled || EffectiveEdition is not { } edition || SelectedBook is not { } book || SelectedChapter is not { } chapter)
        { IsLoading = false; NotifyDisplay(); return; }
        IsLoading = true;
        try
        {
            var text = await _store.LoadChapterAsync(edition.Id, book.Book.Id, chapter.Chapter.Number, cancellation.Token);
            if (request != _request) return;
            _sourceVerses = text.Verses;
            IsPartial = !chapter.Chapter.IsComplete;
            RefreshText();
        }
        catch (OperationCanceledException) { }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or System.Text.Json.JsonException)
        {
            if (request == _request)
            {
                _retryOperation = RetryOperation.Download;
                Error = Loc.Tr("bible_read_error", "This chapter could not be opened. Retry or download the edition again.");
            }
        }
        finally { if (request == _request) { IsLoading = false; NotifyDisplay(); } }
    }
    private void RefreshText()
    {
        Verses = new(_sourceVerses.Select(verse => new BibleVerseRow(verse.Verse, verse.DisplayedText(EffectiveEdition?.Scripture, EffectiveScript), verse.EndVerse)));
        SelectedVerse = Verses.FirstOrDefault(verse => _versePosition is { } position && verse.ContainsVerse(position)) ?? Verses.FirstOrDefault();
        NotifyDisplay();
    }
    public bool SelectVerse(int number)
    {
        var row = Verses.FirstOrDefault(verse => verse.ContainsVerse(number));
        if (row is null) return false;
        SelectedVerse = row;
        VerseRequested?.Invoke(row);
        return true;
    }
    public void RefreshTypography() { RefreshChoices(); RefreshText(); }

    [RelayCommand] private void ToggleScript() { if (HasScriptToggle) ScriptOverride = EffectiveScript == "Syrc" ? "Hebr" : "Syrc"; }
    [RelayCommand] private void PreviousChapter() => Move(-1);
    [RelayCommand] private void NextChapter() => Move(1);
    private void Move(int direction)
    {
        if (Location is not { } current || BibleNavigation.Adjacent(_installed?.Books ?? [], current, direction) is not { } next) return;
        _versePosition = null;
        _synchronizing = true;
        try
        {
            SelectedBook = Books.First(book => book.Book.Id == next.Book);
            RefreshChapters();
            SelectedChapter = Chapters.First(chapter => chapter.Chapter.Number == next.Chapter);
        }
        finally { _synchronizing = false; }
        _ = LoadChapterAsync();
    }

    [RelayCommand]
    private async Task DownloadAsync()
    {
        if (IsDownloading || EffectiveEdition is not { } edition) return;
        _downloadCancellation = new();
        IsDownloading = true;
        Error = null;
        DownloadProgress = 0;
        try { await _store.DownloadAsync(edition.Id, new Progress<double>(value => DownloadProgress = value), _downloadCancellation.Token); }
        catch (OperationCanceledException) { }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or System.Text.Json.JsonException or System.Net.Http.HttpRequestException)
        { _retryOperation = RetryOperation.Download; Error = Loc.Tr("bible_download_error", "The Bible could not be downloaded. Check your connection and retry."); }
        finally { IsDownloading = false; _downloadCancellation.Dispose(); _downloadCancellation = null; }
        var errorText = Error;
        await RefreshAsync();
        Error = errorText;
    }
    [RelayCommand] private void CancelDownload() => _downloadCancellation?.Cancel();
    [RelayCommand]
    private async Task RemoveAsync()
    {
        if (IsDownloading || EffectiveEdition is not { } edition || ConfirmRemoval is null || !await ConfirmRemoval()) return;
        try { await _store.RemoveAsync(edition.Id); await RefreshAsync(); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        { _retryOperation = RetryOperation.Remove; Error = Loc.Tr("bible_remove_error", "The download could not be removed. Please try again."); }
    }
    [RelayCommand]
    private async Task RetryAsync()
    {
        if (IsDownloading) return;
        if (_retryOperation == RetryOperation.Remove) await RemoveAsync();
        else if (_retryOperation == RetryOperation.Download) await DownloadAsync();
        else await LoadChapterAsync();
    }
    public void StopLoading() { ++_request; _chapterCancellation?.Cancel(); _downloadCancellation?.Cancel(); }
    private void NotifyDisplay()
    {
        foreach (var property in new[] { nameof(HasEdition), nameof(IsUnavailable), nameof(EditionName), nameof(ShowDownload), nameof(DownloadLabel),
            nameof(ShowDownloadNotice), nameof(ShowRemove), nameof(Attribution), nameof(SourceUri), nameof(HasSource), nameof(HasScriptToggle),
            nameof(ScriptLabel), nameof(ChapterHeading), nameof(BodyFontFamily), nameof(BodyFontSize), nameof(IsRightToLeft), nameof(HasChapter),
            nameof(CanNavigate), nameof(HasPrevious), nameof(HasNext), nameof(Introduction), nameof(HasIntroduction) }) OnPropertyChanged(property);
    }
}
