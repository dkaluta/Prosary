using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Automation;
using Microsoft.Web.WebView2.Core;
using Prosary.Localization;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Controls;

/// <summary>One locally prepared text document, native lookup controls and edition-wide pages.</summary>
public sealed class BibleEditionTextControl : UserControl
{
    private readonly WebView2 _web = new();
    private readonly Button _previous = new() { MinWidth = 32, MinHeight = 32 };
    private readonly Button _next = new() { MinWidth = 32, MinHeight = 32 };
    private readonly Grid _navigation = new();
    private bool _chromeHidden;
    private int _total;
    public event Action<bool>? ChromeChanged;
    public void RestoreChrome() => SetChromeHidden(false);
    private void SetChromeHidden(bool hidden)
    {
        _chromeHidden = hidden;
        _navigation.Visibility = hidden ? Visibility.Collapsed : Visibility.Visible;
        _slider.Visibility = !hidden && _total > 1 ? Visibility.Visible : Visibility.Collapsed;
        ChromeChanged?.Invoke(hidden);
    }
    private readonly TextBlock _count = new() { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
    private readonly Slider _slider = new() { Minimum = 1, Maximum = 2, Visibility = Visibility.Collapsed };
    private readonly ProgressRing _preparing = new() { IsActive = true, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
    private BibleViewModel? _model;
    private string? _identity;
    private string? _anchor;
    private string? _pendingJump;
    private int _generation;
    private readonly string _documentDirectory = Path.Combine(global::Windows.Storage.ApplicationData.Current.LocalCacheFolder.Path,
        "BibleReader", Guid.NewGuid().ToString("N"));
    private bool _updatingSlider;
    private bool _dialogOpen;
    private IReadOnlyDictionary<string, IReadOnlyList<ScriptureSourceNote>> _notes = new Dictionary<string, IReadOnlyList<ScriptureSourceNote>>();

    public BibleEditionTextControl()
    {
        var root = new Grid { RowSpacing = 8 };
        root.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new() { Height = GridLength.Auto });
        root.RowDefinitions.Add(new() { Height = GridLength.Auto });
        var body = new Grid(); body.Children.Add(_web); body.Children.Add(_preparing); root.Children.Add(body);
        var navigation = _navigation;
        navigation.ColumnDefinitions.Add(new() { Width = GridLength.Auto });
        navigation.ColumnDefinitions.Add(new() { Width = new(1, GridUnitType.Star) });
        navigation.ColumnDefinitions.Add(new() { Width = GridLength.Auto });
        navigation.Children.Add(_previous); navigation.Children.Add(_count); navigation.Children.Add(_next);
        Grid.SetColumn(_count, 1); Grid.SetColumn(_next, 2); Grid.SetRow(navigation, 1); root.Children.Add(navigation);
        Grid.SetRow(_slider, 2); root.Children.Add(_slider); Content = root;
        _previous.Click += async (_, _) => await CommandAsync(new { type = "turn", delta = -1 });
        _next.Click += async (_, _) => await CommandAsync(new { type = "turn", delta = 1 });
        _slider.ValueChanged += async (_, args) => { if (!_updatingSlider) await CommandAsync(new { type = "page", page = (int)args.NewValue - 1 }); };
        AutomationProperties.SetAutomationId(_web, "bibleEditionText");
        AutomationProperties.SetAutomationId(_count, "biblePageCount");
        AutomationProperties.SetAutomationId(_slider, "biblePageSlider");
        AutomationProperties.SetAutomationId(_previous, "biblePreviousPage");
        AutomationProperties.SetAutomationId(_next, "bibleNextPage");
    }

    public async Task ConfigureAsync(BibleViewModel model)
    {
        _model = model;
        if (model.EffectiveEdition is not { } edition || model.ReaderSections.Count == 0)
        {
            _identity = null; Visibility = Visibility.Collapsed; _notes = new Dictionary<string, IReadOnlyList<ScriptureSourceNote>>();
            if (_web.CoreWebView2 is not null) _web.CoreWebView2.Navigate("about:blank");
            return;
        }
        Visibility = Visibility.Visible;
        var identity = $"{edition.Id}|{edition.Revision}|{model.EffectiveScript}|{model.BodyFontFamily}|{model.BodyFontSize}";
        if (_identity == identity) return;
        _identity = identity;
        var generation = ++_generation;
        try
        {
            _preparing.IsActive = true;
            await _web.EnsureCoreWebView2Async();
            if (generation != _generation) return;
            _web.CoreWebView2.WebMessageReceived -= Receive;
            _web.CoreWebView2.WebMessageReceived += Receive;
            _web.CoreWebView2.NavigationStarting -= NavigationStarting;
            _web.CoreWebView2.NavigationStarting += NavigationStarting;
            var sections = new List<object>();
            var notes = new Dictionary<string, IReadOnlyList<ScriptureSourceNote>>();
            foreach (var section in model.ReaderSections)
            {
                var book = section.Book;
                var info = book.Chapters.First(item => item.Number == section.Display.Chapter.Chapter);
                var rows = BibleVerseRow.FromDisplay(section.Display, edition.Scripture, model.EffectiveScript, info.CanonicalReference is not null);
                var blocks = rows.Select(row =>
                {
                    var id = section.Id + "/" + row.Id;
                    if (row.SourceNotes is { Count: > 0 }) notes[id] = row.SourceNotes;
                    return new { id, kind = row.Kind, text = row.Text,
                        label = row.UsesPrintedLabels ? "" : row.Kind == "witness" ? row.PickerLabel ?? row.PrintedLabel ?? "" : row.IsVerseChoice ? row.VerseLabel : "",
                        printed = row.PrintedLabelAnnotation, notes = row.SourceNotes is { Count: > 0 } };
                }).ToArray();
                sections.Add(new { id = section.Id, book = book.Id, bookName = model.EffectiveScript == "Syrc" ? book.TransliteratedName ?? book.Name : book.Name,
                    chapter = info.Number, label = info.CanonicalReference ?? ReadingChapterHeading.Label(edition.LanguageCode, model.EffectiveScript) + " " + ReadingChapterHeading.Number(info.Number, edition.LanguageCode, model.EffectiveScript),
                    partial = !info.IsComplete, introduction = book.IntroductionForChapter(info.Number) ?? "", blocks,
                    attribution = book.Attribution ?? "", sourceURL = book.SourceURL ?? "" });
            }
            _notes = notes;
            var family = model.BodyFontFamily.Split('#')[0].TrimStart('/');
            var fontPath = Path.Combine(AppContext.BaseDirectory, family.Replace('/', Path.DirectorySeparatorChar));
            var font = File.Exists(fontPath) ? Convert.ToBase64String(await File.ReadAllBytesAsync(fontPath)) : "";
            var payload = new { title = edition.Name, language = edition.LanguageCode, rtl = model.IsRightToLeft, font, fontSize = model.BodyFontSize,
                interfaceRTL = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current), chromeTaps = true,
                anchor = _anchor ?? $"{model.SelectedBook?.Book.Id}/{model.SelectedChapter?.Chapter.Number}", sections,
                attribution = edition.Attribution, sourceURL = edition.SourceURL, partialLabel = model.PartialNotice,
                sourceLabel = model.SourceLabel, noteLabel = Loc.Tr("scripture_note_title", "Source note") };
            var template = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "Assets", "edition-reader.html"));
            if (generation != _generation) return;
            Directory.CreateDirectory(_documentDirectory);
            var name = $"edition-{generation}.html";
            await File.WriteAllTextAsync(Path.Combine(_documentDirectory, name),
                template.Replace("__PROSARY_DOCUMENT__", JsonSerializer.Serialize(payload)));
            if (generation != _generation) return;
            _web.CoreWebView2.SetVirtualHostNameToFolderMapping("reader.prosary.local", _documentDirectory, CoreWebView2HostResourceAccessKind.DenyCors);
            _web.Source = new Uri("https://reader.prosary.local/" + name);
            foreach (var previous in Directory.EnumerateFiles(_documentDirectory, "edition-*.html"))
                if (Path.GetFileName(previous) != name) File.Delete(previous);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidOperationException or System.Runtime.InteropServices.COMException)
        {
            if (generation == _generation) { _preparing.IsActive = false; _identity = null; model.Error = Loc.Tr("bible_read_error", "This chapter could not be opened. Retry or download the edition again."); }
        }
    }
    private static void NavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs args)
    { if (args.Uri != "about:blank" && !args.Uri.StartsWith("https://reader.prosary.local/", StringComparison.Ordinal)) args.Cancel = true; }
    public void Jump(string id)
    {
        _anchor = id;
        if (_preparing.IsActive) _pendingJump = id;
        else _ = CommandAsync(new { type = "jump", id });
    }
    private async Task CommandAsync(object command)
    {
        if (_web.CoreWebView2 is null) return;
        try { await _web.ExecuteScriptAsync($"window.ProsaryReader?.command({JsonSerializer.Serialize(command)})"); }
        catch (InvalidOperationException) { }
        catch (System.Runtime.InteropServices.COMException) { }
    }
    private async void Receive(object? sender, CoreWebView2WebMessageReceivedEventArgs args)
    {
        if (_model is null) return;
        try
        {
            using var document = JsonDocument.Parse(args.TryGetWebMessageAsString());
            var message = document.RootElement;
            switch (message.GetProperty("type").GetString())
            {
                case "state":
                    _preparing.IsActive = false;
                    var page = message.GetProperty("page").GetInt32(); var total = message.GetProperty("total").GetInt32(); var leaves = message.GetProperty("leaves").GetInt32();
                    _anchor = message.GetProperty("anchor").GetString();
                    _model.SelectReaderPosition(message.GetProperty("book").GetString()!, message.GetProperty("chapter").GetInt32(), _anchor!);
                    _count.Text = string.Format(Loc.Tr("bible_page_count", "Pages {0}–{1} of {2}"), page, Math.Min(page + leaves - 1, total), total);
                    _previous.IsEnabled = page > 1; _next.IsEnabled = page + leaves <= total;
                    _previous.Content = new SymbolIcon(_model.IsRightToLeft ? Symbol.Forward : Symbol.Back);
                    _next.Content = new SymbolIcon(_model.IsRightToLeft ? Symbol.Back : Symbol.Forward);
                    AutomationProperties.SetName(_previous, Loc.Tr("bible_previous_page", "Previous Page"));
                    AutomationProperties.SetName(_next, Loc.Tr("bible_next_page", "Next Page"));
                    AutomationProperties.SetName(_slider, _count.Text);
                    _total = total;
                    _updatingSlider = true; _slider.Maximum = Math.Max(2, total); _slider.Value = page; _slider.Visibility = !_chromeHidden && total > 1 ? Visibility.Visible : Visibility.Collapsed;
                    _slider.FlowDirection = _model.IsRightToLeft ? FlowDirection.RightToLeft : FlowDirection.LeftToRight; _updatingSlider = false;
                    if (_pendingJump is { } jump) { _pendingJump = null; await CommandAsync(new { type = "jump", id = jump }); }
                    break;
                case "chrome":
                    SetChromeHidden(message.TryGetProperty("hidden", out var hidden) ? hidden.GetBoolean() : !_chromeHidden);
                    break;
                case "note":
                    if (_dialogOpen || XamlRoot is null || !_notes.TryGetValue(message.GetProperty("id").GetString()!, out var notes)) break;
                    _dialogOpen = true;
                    try { await new ContentDialog { XamlRoot = XamlRoot, Content = new ScrollViewer { Content = new ScriptureSourceNotesControl { SourceNotes = notes } },
                        CloseButtonText = Loc.Tr("common_done", "Done") }.ShowAsync(); }
                    finally { _dialogOpen = false; }
                    break;
                case "link":
                    if (Uri.TryCreate(message.GetProperty("url").GetString(), UriKind.Absolute, out var uri) && uri.Scheme == "https")
                        await global::Windows.System.Launcher.LaunchUriAsync(uri);
                    break;
            }
        }
        catch (JsonException) { }
    }
}
