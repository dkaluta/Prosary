using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record ReadingEditionChoice(string Id, string Label);
public sealed record ReadingChapterSection(string Label, int Number, string DisplayNumber, string Text, IReadOnlyList<BibleVerseRow>? Verses = null);

/// <summary>Each full citation keeps an independent, lazy Bible-text expansion.</summary>
public partial class ReadingPassageViewModel : ObservableObject
{
    private readonly ReadingsTextStore _store;
    private readonly ScriptureEdition? _edition;
    private readonly string _scope;
    private readonly string _rawCitation;
    private readonly string? _readingDatasetId;
    private readonly string? _sourceGroupCaption;
    private bool _didLoad;
    private IReadOnlyList<ScriptureVerse> _verses = [];
    private ScripturePassage? _passage;
    public string ContextKey { get; }
    public string ConfigurationKey { get; }
    public string Citation { get; }
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasSourceGroup))]
    private string? _sourceGroup;
    public bool HasSourceGroup => !string.IsNullOrWhiteSpace(SourceGroup);
    public string PassageLabel => Loc.Tr("readings_bible_passage", "Bible Passage");
    public string EditionName => _edition?.Name ?? Loc.Tr("readings_edition_unavailable", "No edition is available for this language.");
    public string UnavailableText => Loc.Tr("readings_text_unavailable", "This passage is not available in the selected Bible edition.");
    public string TextNotice => Loc.Tr("readings_text_notice", "Bible text for the cited passage. The wording may differ from the Mass reading.");
    public string WholeVersesNotice => Loc.Tr("readings_whole_verses_notice", "Full verses are shown and may extend beyond the reading’s cited limits.");
    public string SourceLabel => Loc.Tr("readings_source", "Source and Edition");
    public string EditionLabel => Loc.Tr("readings_edition", "Bible Edition");
    public string SourceName => _passage?.Source?.Name ?? "";
    public bool HasSourceName => !string.IsNullOrEmpty(SourceName);
    public bool IsPartial => _passage?.Source?.IsComplete == false;
    public string PartialNotice => Loc.Tr("bible_partial_chapter", "Only part of this chapter is available.");
    public string Attribution => _passage?.Source?.Attribution ?? _edition?.Attribution ?? "";
    public Uri? SourceUri => _passage?.Source?.SourceUri ?? _edition?.SourceUri;
    public bool HasSource => SourceUri is not null;
    private PrayerTypography.Script PassageScript => PrayerTypography.ScriptOf(string.Concat(
        _verses.Select(verse => verse.DisplayedText(_edition, EffectiveScript)))
        + string.Concat(_passage?.Source?.ContentBlocks?.Select(block => block.Text) ?? []));
    public bool IsRightToLeft => PrayerTypography.IsRightToLeft(PassageScript);
    public string BodyFontFamily => PrayerTypography.ResolveBodyFontFamily(_edition?.LanguageCode,
        isScripture: true, PassageScript);
    public double BodyFontSize => PrayerTypography.ResolveBodyFontSize(_edition?.LanguageCode,
        isScripture: true, PassageScript);
    public string EffectiveScript => ScriptOverride ?? AppSettings.AramaicDefaultScript;
    public string CurrentScriptLabel => EffectiveScript == "Syrc"
        ? Loc.Tr("settings_script_syriac", "Syriac Script") : Loc.Tr("settings_script_hebrew", "Hebrew Script");
    public string ScriptToggleLabel => EffectiveScript == "Syrc"
        ? Loc.Tr("settings_script_hebrew", "Hebrew Script") : Loc.Tr("settings_script_syriac", "Syriac Script");

    [ObservableProperty]
    private string? _scriptOverride;

    [ObservableProperty]
    private bool _hasScriptToggle;

    [ObservableProperty]
    private bool _isExpanded;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(BodyFontFamily))]
    [NotifyPropertyChangedFor(nameof(BodyFontSize))]
    [NotifyPropertyChangedFor(nameof(IsRightToLeft))]
    private string _passageText = "";

    [ObservableProperty]
    private IReadOnlyList<ReadingChapterSection> _chapters = [];

    [ObservableProperty]
    private bool _includesWholeVerses;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsUnavailable))]
    private bool _hasPassage;
    public bool IsUnavailable => !HasPassage;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasAvailableEditions))]
    private IReadOnlyList<ReadingEditionChoice> _availableEditions = [];
    public bool HasAvailableEditions => AvailableEditions.Count > 0;

    [ObservableProperty]
    private ReadingEditionChoice? _selectedAvailableEdition;

    public ReadingPassageViewModel(ReadingsTextStore store, ScriptureEdition? edition, string scope,
        ReadingCitation citation, string interfaceLanguage, string contextKey, string configurationKey, bool showsSourceGroup = true)
    {
        _store = store;
        _edition = edition;
        _scope = scope;
        _rawCitation = citation.Full;
        _readingDatasetId = citation.ReadingDatasetId;
        _sourceGroupCaption = citation.SourceGroup;
        Citation = citation.LocalizedFull(interfaceLanguage);
        SourceGroup = showsSourceGroup ? citation.SourceGroup : null;
        ContextKey = contextKey;
        ConfigurationKey = configurationKey;
    }

    public void ShowSourceGroupHeading(bool showsHeading) => SourceGroup = showsHeading ? _sourceGroupCaption : null;

    async partial void OnIsExpandedChanged(bool value)
    {
        if (!value || _didLoad) return;
        _didLoad = true;
        var passage = _edition is null ? null : await _store.LoadPassageAsync(_scope, _rawCitation, _edition.Id, _readingDatasetId);
        _passage = passage;
        _verses = passage?.Verses ?? [];
        HasPassage = _verses.Count > 0;
        AvailableEditions = HasPassage ? [] : _store.AvailableEditions(_scope, _rawCitation, _readingDatasetId)
            .Select(edition => new ReadingEditionChoice(edition.Id, edition.Name)).ToList();
        HasScriptToggle = HasPassage && _edition?.HasAramaicScripts == true;
        IncludesWholeVerses = passage?.IncludesWholeVerses ?? false;
        OnPropertyChanged(nameof(SourceName));
        OnPropertyChanged(nameof(HasSourceName));
        OnPropertyChanged(nameof(IsPartial));
        OnPropertyChanged(nameof(Attribution));
        OnPropertyChanged(nameof(SourceUri));
        OnPropertyChanged(nameof(HasSource));
        RefreshDisplayedText();
    }

    partial void OnScriptOverrideChanged(string? value) => RefreshDisplayedText();

    partial void OnSelectedAvailableEditionChanged(ReadingEditionChoice? value)
    {
        if (value is not null && AvailableEditions.Any(edition => edition.Id == value.Id))
            AppSettings.SetReadingsEditionId(value.Id);
    }

    [RelayCommand]
    private void ToggleScript()
    {
        if (HasScriptToggle) ScriptOverride = EffectiveScript == "Syrc" ? "Hebr" : "Syrc";
    }

    private void RefreshDisplayedText()
    {
        var sections = new List<ReadingChapterSection>();
        var headingLanguage = _edition?.LanguageCode ?? "en";
        var chapterLabel = ReadingChapterHeading.Label(headingLanguage, EffectiveScript);
        if (_edition is not null && _passage?.SourceDisplays(_edition) is { } displays)
        {
            foreach (var display in displays)
            {
                var rows = BibleVerseRow.FromDisplay(display, _edition, EffectiveScript);
                sections.Add(new ReadingChapterSection(chapterLabel, display.Chapter.Chapter,
                    ReadingChapterHeading.Number(display.Chapter.Chapter, headingLanguage, EffectiveScript),
                    string.Join(Environment.NewLine + Environment.NewLine, rows.Select(row => row.DisplayText)), rows));
            }
        }
        else foreach (var verse in _verses)
        {
            var text = $"\u2066{verse.VerseLabel}\u2069  {verse.DisplayedText(_edition, EffectiveScript)}";
            var row = new BibleVerseRow(verse.Verse, verse.DisplayedText(_edition, EffectiveScript), verse.EndVerse, verse.SourceNotes);
            if (sections.Count == 0 || sections[^1].Number != verse.Chapter)
                sections.Add(new ReadingChapterSection(chapterLabel, verse.Chapter,
                    ReadingChapterHeading.Number(verse.Chapter, headingLanguage, EffectiveScript), text, [row]));
            else
                sections[^1] = sections[^1] with { Text = sections[^1].Text + Environment.NewLine + Environment.NewLine + text,
                    Verses = [.. sections[^1].Verses ?? [], row] };
        }
        Chapters = sections;
        PassageText = string.Join(Environment.NewLine + Environment.NewLine,
            sections.Select(section => $"{section.Label} \u2068{section.DisplayNumber}\u2069{Environment.NewLine}{section.Text}"));
        OnPropertyChanged(nameof(EffectiveScript));
        OnPropertyChanged(nameof(CurrentScriptLabel));
        OnPropertyChanged(nameof(ScriptToggleLabel));
    }

    public void RefreshTypography()
    {
        // Follow changes to the app's script default until this passage gets a local override.
        RefreshDisplayedText();
        OnPropertyChanged(nameof(BodyFontFamily));
        OnPropertyChanged(nameof(BodyFontSize));
    }
}

public partial class DesktopReadingsViewModel : ObservableObject
{
    private readonly ReadingsTextStore _store;
    private HomeViewModel? _today;
    private bool _synchronizing;
    private bool _showsAllDailyReadings;
    public string EditionLabel => Loc.Tr("readings_edition", "Bible Edition");
    public ObservableCollection<ReadingEditionChoice> Editions { get; }

    [ObservableProperty]
    private ReadingEditionChoice? _selectedEdition;

    [ObservableProperty]
    private ObservableCollection<ReadingPassageViewModel> _daily = [];

    [ObservableProperty]
    private ObservableCollection<ReadingPassageViewModel> _torah = [];

    public DesktopReadingsViewModel(ReadingsTextStore? store = null)
    {
        _store = store ?? ReadingsTextStore.Default;
        Editions = new ObservableCollection<ReadingEditionChoice>(
            new[] { new ReadingEditionChoice("", Loc.Tr("readings_edition_automatic", "Follow Interface Language")) }
                .Concat(_store.Editions.Select(edition => new ReadingEditionChoice(edition.Id, edition.Name))));
        SynchronizeEdition();
    }

    partial void OnSelectedEditionChanged(ReadingEditionChoice? value)
    {
        if (_synchronizing || value is null) return;
        AppSettings.SetReadingsEditionId(value.Id);
        if (_today is not null) Refresh(_today);
    }

    private void SynchronizeEdition()
    {
        _synchronizing = true;
        try
        {
            var id = AppSettings.ReadingsEditionId;
            var choice = Editions.FirstOrDefault(edition => edition.Id == id);
            if (choice is null)
            {
                choice = new ReadingEditionChoice(id, Loc.Tr("readings_edition_unavailable", "No edition is available for this language."));
                Editions.Add(choice);
            }
            SelectedEdition = choice;
        }
        finally { _synchronizing = false; }
    }

    public void Refresh(HomeViewModel today)
    {
        _today = today;
        SynchronizeEdition();
        var edition = _store.ResolveEdition(AppSettings.ReadingsEditionId, today.TodayLanguage);
        // The dedicated reader remains available when the optional Today card is hidden.
        var daily = _showsAllDailyReadings ? TodayInfoStore.Readings(today.SelectedDate) : today.TodayReadings;
        Daily = Rows(Daily, daily, "daily", today, edition);
        Torah = Rows(Torah, today.TodayTorahPortion?.Readings ?? [], "torah", today, edition);
    }

    public void Open(HomeViewModel today, bool showsAllDailyReadings = false)
    {
        _showsAllDailyReadings = showsAllDailyReadings;
        Refresh(today);
        foreach (var row in Daily.Concat(Torah)) row.IsExpanded = AppSettings.ExpandReadingsByDefault;
    }

    private ObservableCollection<ReadingPassageViewModel> Rows(ObservableCollection<ReadingPassageViewModel> previous,
        IReadOnlyList<ReadingCitation> citations, string scope, HomeViewModel today, ScriptureEdition? edition)
    {
        var reverse = scope == "daily" && AppSettings.ReverseReadingsOrder;
        var displayed = ReadingCitation.DisplayOrder(citations, reverse);
        var rows = displayed.Select((citation, displayIndex) =>
        {
            // Identity follows the source appointment, so a display-order change retains
            // that reading's manual expansion and selected edition.
            var index = reverse ? citations.Count - 1 - displayIndex : displayIndex;
            var contextKey = $"{today.SelectedDate:yyyy-MM-dd}|{TodayInfoStore.ResolvedCalendarId}|{AppSettings.EasternPaschaStyle}|{scope}|{citation.ReadingDatasetId}|{index}|{citation.Full}|{today.TodayLanguage}";
            var configurationKey = $"{contextKey}|{AppSettings.ReadingsEditionId}|{edition?.Id}";
            var old = previous.FirstOrDefault(row => row.ContextKey == contextKey);
            var showsGroup = displayIndex == 0 || displayed[displayIndex - 1].SourceGroup != citation.SourceGroup;
            if (old?.ConfigurationKey == configurationKey)
            {
                old.ShowSourceGroupHeading(showsGroup);
                return old;
            }
            return new ReadingPassageViewModel(_store, edition, scope, citation, today.TodayLanguage, contextKey, configurationKey,
                showsGroup)
            { IsExpanded = old?.IsExpanded ?? AppSettings.ExpandReadingsByDefault };
        }).ToList();
        return previous.SequenceEqual(rows) ? previous : new ObservableCollection<ReadingPassageViewModel>(rows);
    }

    public void RefreshTypography()
    {
        foreach (var row in Daily.Concat(Torah)) row.RefreshTypography();
    }
}
