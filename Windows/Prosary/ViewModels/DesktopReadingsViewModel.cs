using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record ReadingEditionChoice(string Id, string Label);

/// <summary>Each full citation keeps an independent, lazy Bible-text expansion.</summary>
public partial class ReadingPassageViewModel : ObservableObject
{
    private readonly ReadingsTextStore _store;
    private readonly ScriptureEdition? _edition;
    private readonly string _scope;
    private readonly string _rawCitation;
    private bool _didLoad;
    private IReadOnlyList<ScriptureVerse> _verses = [];
    public string ContextKey { get; }
    public string ConfigurationKey { get; }
    public string Citation { get; }
    public string PassageLabel => Loc.Tr("readings_bible_passage", "Bible Passage");
    public string EditionName => _edition?.Name ?? Loc.Tr("readings_edition_unavailable", "No edition is available for this language.");
    public string UnavailableText => Loc.Tr("readings_text_unavailable", "This passage is not available in the selected Bible edition.");
    public string TextNotice => Loc.Tr("readings_text_notice", "Bible text for the cited passage. The wording may differ from the Mass reading.");
    public string WholeVersesNotice => Loc.Tr("readings_whole_verses_notice", "Full verses are shown and may extend beyond the reading’s cited limits.");
    public string SourceLabel => Loc.Tr("readings_source", "Source and Edition");
    public string EditionLabel => Loc.Tr("readings_edition", "Bible Edition");
    public string Attribution => _edition?.Attribution ?? "";
    public Uri? SourceUri => _edition?.SourceUri;
    public bool HasSource => SourceUri is not null;
    public bool IsRightToLeft => PrayerTypography.IsRightToLeft(PrayerTypography.ScriptOf(PassageText));
    public string BodyFontFamily => PrayerTypography.ResolveBodyFontFamily(_edition?.LanguageCode,
        isScripture: true, PrayerTypography.ScriptOf(PassageText));
    public double BodyFontSize => PrayerTypography.ResolveBodyFontSize(_edition?.LanguageCode,
        isScripture: true, PrayerTypography.ScriptOf(PassageText));
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
        ReadingCitation citation, string interfaceLanguage, string contextKey, string configurationKey)
    {
        _store = store;
        _edition = edition;
        _scope = scope;
        _rawCitation = citation.Full;
        Citation = citation.LocalizedFull(interfaceLanguage);
        ContextKey = contextKey;
        ConfigurationKey = configurationKey;
    }

    partial void OnIsExpandedChanged(bool value)
    {
        if (!value || _didLoad) return;
        _didLoad = true;
        var passage = _edition is null ? null : _store.LoadPassage(_scope, _rawCitation, _edition.Id);
        _verses = passage?.Verses ?? [];
        HasPassage = _verses.Count > 0;
        AvailableEditions = HasPassage ? [] : _store.AvailableEditions(_scope, _rawCitation)
            .Select(edition => new ReadingEditionChoice(edition.Id, edition.Name)).ToList();
        HasScriptToggle = HasPassage && _edition?.HasAramaicScripts == true;
        IncludesWholeVerses = passage?.IncludesWholeVerses ?? false;
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
        PassageText = string.Join(Environment.NewLine + Environment.NewLine,
            _verses.Select(verse => $"\u2066{verse.Chapter}:{verse.Verse}\u2069  {verse.DisplayedText(_edition, EffectiveScript)}"));
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
        Daily = Rows(Daily, today.TodayReadings, "daily", today, edition);
        Torah = Rows(Torah, today.TodayTorahPortion?.Readings ?? [], "torah", today, edition);
    }

    public void Open(HomeViewModel today)
    {
        Refresh(today);
        foreach (var row in Daily.Concat(Torah)) row.IsExpanded = true;
    }

    private ObservableCollection<ReadingPassageViewModel> Rows(ObservableCollection<ReadingPassageViewModel> previous,
        IReadOnlyList<ReadingCitation> citations, string scope, HomeViewModel today, ScriptureEdition? edition)
    {
        var rows = citations.Select((citation, index) =>
        {
            var contextKey = $"{today.SelectedDate:yyyy-MM-dd}|{TodayInfoStore.ResolvedCalendarId}|{AppSettings.EasternPaschaStyle}|{scope}|{index}|{citation.Full}|{today.TodayLanguage}";
            var configurationKey = $"{contextKey}|{AppSettings.ReadingsEditionId}|{edition?.Id}";
            var old = previous.FirstOrDefault(row => row.ContextKey == contextKey);
            if (old?.ConfigurationKey == configurationKey) return old;
            return new ReadingPassageViewModel(_store, edition, scope, citation, today.TodayLanguage, contextKey, configurationKey)
            { IsExpanded = old?.IsExpanded ?? true };
        }).ToList();
        return previous.SequenceEqual(rows) ? previous : new ObservableCollection<ReadingPassageViewModel>(rows);
    }

    public void RefreshTypography()
    {
        foreach (var row in Daily.Concat(Torah)) row.RefreshTypography();
    }
}
