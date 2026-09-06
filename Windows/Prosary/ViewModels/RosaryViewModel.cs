using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Microsoft.UI;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the Rosary prayer flow. Ported from irosary's <c>RosaryViewModel.cs</c> — the bead-row
/// building algorithm (<see cref="RebuildBeads"/>) is unchanged; retargeted from
/// <c>RosaryConfig</c>/Shell's <c>[QueryProperty]</c> loading to <see cref="Prayer"/>/an explicit
/// <see cref="LoadAsync"/> the page calls directly (plain WinUI3 has no Shell query-property
/// mechanism), and the Apple-only native-serif branch is gone (Windows always uses
/// <see cref="PrayerTypography"/>'s Cambria/bundled-font resolution).
/// </summary>
public partial class RosaryViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly PrayerEngine _engine;
    private readonly IPrayerRunStore _runStore;

    private IReadOnlyList<RosaryStep> _steps = [];
    private int _index;
    private string _languageCode = LanguageCatalog.DefaultCode;
    private string _chosenLanguage = LanguageCatalog.DefaultSentinel;
    private Prayer? _activePrayer;
    private Prayer? _initialPrayer;
    private PrayerRunState? _pendingContinuation;
    private string _runKey = string.Empty;
    private string _runSignature = string.Empty;
    private bool _isSavedPrayer;

    // Precomputed once per session load (not per step) — how many decades this session has,
    // whether it ends with a Sign of the Cross, and where the antiphon (if any) sits, so
    // RenderCurrentStep's bead rebuild doesn't need to re-derive them on every button press.
    private int _totalDecades;
    private int _firstDecadeStepIndex = -1;
    private int _antiphonStepIndex = -1;
    private bool _hasClosingCross;

    [ObservableProperty]
    private string _header = string.Empty;

    [ObservableProperty]
    private string? _subtitle;

    [ObservableProperty]
    private string _body = string.Empty;

    [ObservableProperty]
    private string _mysteryImageKey = "cross_placeholder";

    [ObservableProperty]
    private string _progressText = string.Empty;

    [ObservableProperty]
    private string _progressFontFamily = Microsoft.UI.Xaml.Media.FontFamily.XamlAutoFontFamily.Source;

    private string? _initializedScriptLanguage;
    private string? _aramaicSessionScript;

    [ObservableProperty]
    private double? _progress;

    [ObservableProperty]
    private bool _canGoBack;

    [ObservableProperty]
    private bool _canGoToPreviousMystery;

    [ObservableProperty]
    private bool _canGoToNextMystery;

    [ObservableProperty]
    private bool _isLastStep;

    [ObservableProperty]
    private bool _isRightToLeft;

    [ObservableProperty]
    private Color _seasonColor = Color.FromArgb(0, 0, 0, 0);

    [ObservableProperty]
    private string _bodyFontFamily = "Cambria";

    [ObservableProperty]
    private double _bodyFontSize = 18;

    // Alternate-script reading aid. Aramaic mystery announcements use Hebrew-square
    // Peshitta text as their primary body and the source Syriac as this per-step alternate.
    [ObservableProperty]
    private bool _hasTransliteration;

    [ObservableProperty]
    private bool _showsTransliteration;

    [RelayCommand]
    private void ToggleTransliteration()
    {
        if (_aramaicSessionScript is not null)
            _aramaicSessionScript = _aramaicSessionScript == "Syrc" ? "Hebr" : "Syrc";
        else ShowsTransliteration = !ShowsTransliteration;
        RenderCurrentStep();
    }

    // Decade beads grouped into rows of 5 — like the physical layout of a rosary's Our-Father
    // beads — for the narrow layout's wrapped horizontal grid. See BeadLayout.Build.
    [ObservableProperty]
    private ObservableCollection<IReadOnlyList<BeadInfo>> _topBeadRows = [];

    // Wide layout's major-beads column: opening cross, then one column per mystery group in the
    // session (side by side), then the antiphon/closing-cross beads — matches iOS's
    // BeadProgressView wide layout exactly (see that file's doc comment for why: a plain
    // rows-of-4 vertical track, which this project used before, has no precedent on either other
    // platform and doesn't reflect how a 15/20-mystery session's decades actually group).
    [ObservableProperty]
    private BeadInfo? _openingCross;

    [ObservableProperty]
    private ObservableCollection<BeadColumn> _groupColumns = [];

    [ObservableProperty]
    private BeadInfo? _antiphonBead;

    [ObservableProperty]
    private BeadInfo? _closingCross;

    [ObservableProperty]
    private ObservableCollection<BeadInfo> _bottomBeads = [];

    [ObservableProperty]
    private bool _showBottomBeads;

    /// <summary>Whether the wide layout's minor-bead track has enough vertical room for a single
    /// 10-tall column — set by the page from its own measured height (see
    /// <c>RosaryPrayerPage.xaml.cs</c>'s <c>WideMinorColumnHeightThreshold</c>), matching iOS's
    /// <c>GeometryReader</c>-measured <c>hasRoomForSingleMinorColumn</c>. Ignored in the narrow
    /// layout, which always uses a single row regardless of height.</summary>
    [ObservableProperty]
    private bool _hasRoomForSingleMinorColumn = true;

    /// <summary>Set by the page from its own <c>FrameworkElement.ActualTheme</c> (initially, and
    /// again on <c>ActualThemeChanged</c>) — beads are plain data rebuilt on every step change,
    /// not live XAML elements bindable to a <c>{ThemeResource}</c>, so the current bead's color
    /// (the one bead color that differs by theme — see BeadInfo.cs) needs this threaded through
    /// explicitly instead.</summary>
    [ObservableProperty]
    private bool _hasDarkTheme;

    partial void OnHasDarkThemeChanged(bool value) => RebuildBeads();

    /// <summary>First half of <see cref="BottomBeads"/>, for the wide layout's split-column
    /// fallback when <see cref="HasRoomForSingleMinorColumn"/> is false — matches iOS's
    /// <c>MinorBeadsTwoColumnView</c> split exactly (first <c>(count+1)/2</c> beads).</summary>
    public IReadOnlyList<BeadInfo> BottomBeadsColumn1 => BottomBeads.Take((BottomBeads.Count + 1) / 2).ToList();

    public IReadOnlyList<BeadInfo> BottomBeadsColumn2 => BottomBeads.Skip((BottomBeads.Count + 1) / 2).ToList();

    public string MysteryImageFile => PrayerPackStore.ImageFileUriOrPlaceholder(MysteryImageKey);

    public string NextButtonText => IsLastStep ? Loc.Tr("common_finish", "Finish") : Loc.Tr("common_next", "Next");

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    public IReadOnlyList<LanguageOption> Languages { get; private set; } = [];

    public bool ShowsLanguageMenu => Languages.Count > 1;

    public string CurrentLanguageRaw => _chosenLanguage;

    public bool HasSavedContinuation => _pendingContinuation is not null;

    public RosaryViewModel(
        IPresetStore presets,
        PrayerEngine engine,
        LiturgicalCalendarService calendar,
        IPrayerRunStore runStore)
    {
        _presets = presets;
        _engine = engine;
        _runStore = runStore;
        SeasonColor = calendar.GetSeasonColorForToday();
    }

    public async Task LoadAsync(Guid? prayerId)
    {
        ResetContinuationState();
        var prayer = prayerId is { } id ? await _presets.GetAsync(id) : null;
        prayer ??= await _presets.GetDefaultAsync(PrayerKind.Rosary);
        if (prayer is null)
        {
            Header = Loc.Tr("rosary_no_favorites_header", "No Rosary favorites yet");
            Body = Loc.Tr("rosary_no_favorites_body", "Add a Rosary favorite first.");
            return;
        }

        LoadFrom(prayer, isSavedPrayer: true, PrayerRunKeys.Rosary(prayer.Id));
    }

    /// <summary>An ad-hoc, unsaved session from the preset picker's "Pray any Rosary" — the
    /// same build as a saved favorite, just without the store roundtrip.</summary>
    public void LoadAdHoc(Prayer prayer)
    {
        ResetContinuationState();
        LoadFrom(prayer, isSavedPrayer: false, "rosary:adhoc");
    }

    private void ResetContinuationState()
    {
        _pendingContinuation = null;
        OnPropertyChanged(nameof(HasSavedContinuation));
    }

    private void LoadFrom(Prayer prayer, bool isSavedPrayer, string runKey)
    {
        try
        {
            _initialPrayer = prayer;
            _isSavedPrayer = isSavedPrayer;
            _runKey = runKey;
            _runSignature = PrayerRunSignatures.Rosary(prayer.Rosary);
            Languages = LanguageCatalog.AvailableOptions(PrayerPackStore.Info("rosary")?.Languages ?? []);
            OnPropertyChanged(nameof(ShowsLanguageMenu));

            ConfigureSession(prayer, 0);

            var saved = _runStore.Get(_runKey);
            _pendingContinuation = saved?.CanResume(
                _runSignature,
                _steps.Count,
                sameLocalDayOnly: true,
                DateOnly.FromDateTime(DateTime.Now)) == true
                ? saved
                : null;
            if (saved is not null && _pendingContinuation is null)
            {
                _runStore.Remove(_runKey);
            }
            OnPropertyChanged(nameof(HasSavedContinuation));
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[RosaryViewModel] Failed to load Rosary session: {ex}");
            Header = Loc.Tr("flow_error_header", "Something went wrong");
            Body = Loc.Tr("rosary_error_body", "This Rosary session couldn't be loaded. Please go back and try again.");
        }
    }

    private void ConfigureSession(Prayer prayer, int position)
    {
        _activePrayer = prayer;
        _chosenLanguage = prayer.LanguageCode;
        _languageCode = prayer.ResolvedLanguageCode;
        IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
        _steps = _engine.BuildSteps(prayer);
        _index = Math.Clamp(position, 0, Math.Max(_steps.Count - 1, 0));

        _totalDecades = _steps.Any(s => s.DecadeIndex.HasValue)
            ? _steps.Where(s => s.DecadeIndex.HasValue).Max(s => s.DecadeIndex!.Value) + 1
            : 0;
        _firstDecadeStepIndex = _steps.Select((s, i) => (s, i)).Where(t => t.s.DecadeIndex.HasValue)
            .Select(t => (int?)t.i).FirstOrDefault() ?? -1;
        _antiphonStepIndex = _steps.Select((s, i) => (s, i)).Where(t => t.s.IsAntiphon)
            .Select(t => (int?)t.i).FirstOrDefault() ?? -1;
        _hasClosingCross = prayer.Rosary.IncludeFinalSignOfCross;

        OnPropertyChanged(nameof(CurrentLanguageRaw));
        RenderCurrentStep();
    }

    public void ContinueSavedRun()
    {
        if (_pendingContinuation is not { } saved || _activePrayer is null)
        {
            return;
        }

        _pendingContinuation = null;
        OnPropertyChanged(nameof(HasSavedContinuation));
        ConfigureSession(_activePrayer with { LanguageCode = saved.LanguageCode }, saved.Position);
        SaveProgress();
    }

    public void RestartRun()
    {
        _pendingContinuation = null;
        OnPropertyChanged(nameof(HasSavedContinuation));
        if (!string.IsNullOrEmpty(_runKey)) _runStore.Remove(_runKey);
        if (_initialPrayer is { } prayer) ConfigureSession(prayer, 0);
    }

    /// <summary>Changes only the prayer text while preserving the exact current bead/mystery.
    /// A saved preset follows the choice, and an interrupted run checkpoints it too.</summary>
    public async Task SelectLanguageAsync(string raw)
    {
        if (_activePrayer is null) return;

        var position = _index;
        var changed = _activePrayer with { LanguageCode = raw };
        ConfigureSession(changed, position);
        SaveProgress();
        if (_isSavedPrayer)
        {
            await _presets.SaveAsync(changed);
        }
    }

    partial void OnMysteryImageKeyChanged(string value) => OnPropertyChanged(nameof(MysteryImageFile));

    partial void OnIsLastStepChanged(bool value) => OnPropertyChanged(nameof(NextButtonText));

    partial void OnSubtitleChanged(string? value) => OnPropertyChanged(nameof(HasSubtitle));

    partial void OnBottomBeadsChanged(ObservableCollection<BeadInfo> value)
    {
        OnPropertyChanged(nameof(BottomBeadsColumn1));
        OnPropertyChanged(nameof(BottomBeadsColumn2));
    }

    public void RefreshTypography() => RenderCurrentStep();

    private void RenderCurrentStep()
    {
        if (_steps.Count == 0)
        {
            return;
        }

        var step = _steps[_index];
        if (_initializedScriptLanguage != _languageCode)
        {
            _initializedScriptLanguage = _languageCode;
            _aramaicSessionScript = _languageCode == "arc" ? AppSettings.AramaicDefaultScript : null;
        }
        if (_aramaicSessionScript is not null)
            ShowsTransliteration = PrayerTranslations.InitialTransliteration(_languageCode, step.Body, step.TransliteratedBody, _aramaicSessionScript) ?? false;
        Subtitle = HebrewDisplayText.WithoutMarksOrNull(step.Subtitle);
        HasTransliteration = step.TransliteratedBody is not null;
        Body = ShowsTransliteration && step.TransliteratedBody is { } transliterated
            ? transliterated
            : step.Body;
        var usesSyriacScript = _aramaicSessionScript is not null ? _aramaicSessionScript == "Syrc"
            : PrayerTypography.ScriptOf(Body) == PrayerTypography.Script.Syriac;
        Header = PrayerTranslations.FlowTitle(step.Title, _languageCode, usesSyriacScript);
        MysteryImageKey = step.ImageVariantKey ?? step.Mystery?.ImageKey ?? step.ImageOverrideKey ?? "cross_placeholder";
        var aramaicProgress = PrayerTranslations.AramaicProgress(_index + 1, _steps.Count, _languageCode, usesSyriacScript);
        ProgressText = aramaicProgress ?? string.Format(Loc.Tr("flow_step_of", "{0} of {1}"), _index + 1, _steps.Count);
        ProgressFontFamily = aramaicProgress is null ? Microsoft.UI.Xaml.Media.FontFamily.XamlAutoFontFamily.Source
            : PrayerTypography.ResolveBodyFontFamily(_languageCode, false, PrayerTypography.ScriptOf(ProgressText));
        Progress = (_index + 1) / (double)_steps.Count;
        CanGoBack = _index > 0;
        CanGoToPreviousMystery = MysteryStepNavigation.Previous(_steps, _index) is not null;
        CanGoToNextMystery = MysteryStepNavigation.Next(_steps, _index) is not null;
        IsLastStep = _index == _steps.Count - 1;

        // The alternate can be a different script from the prayer language (notably Syriac
        // beside Hebrew-square Aramaic), so choose the face from the body actually on screen.
        var bodyScript = PrayerTypography.ScriptOf(Body);
        IsRightToLeft = PrayerTypography.IsRightToLeft(bodyScript);
        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, step.IsScripture, bodyScript);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, step.IsScripture, bodyScript);

        RebuildBeads();
    }

    private void RebuildBeads()
    {
        var layout = BeadLayout.Build(_steps, _index, _hasClosingCross, HasDarkTheme);

        TopBeadRows = new ObservableCollection<IReadOnlyList<BeadInfo>>(layout.TopRows);
        OpeningCross = layout.OpeningCross;
        GroupColumns = new ObservableCollection<BeadColumn>(layout.GroupColumns);
        AntiphonBead = layout.Antiphon;
        ClosingCross = layout.ClosingCross;
        BottomBeads = new ObservableCollection<BeadInfo>(layout.BottomBeads);
        ShowBottomBeads = layout.ShowBottomBeads;
    }

    public Func<Task<bool>>? OfferLitany { get; set; }
    IRelayCommand IPrayerStepFlowViewModel.NextCommand => NextCommand;

    internal static CustomDevotionFlowParams LitanyContinuation(string languageCode) =>
        new(null, "litanyOfLoreto", languageCode, "afterRosary");

    [RelayCommand]
    private async Task Next()
    {
        if (IsLastStep)
        {
            ClearProgress();
            var prayLitany = PrayerPackStore.Definition("litanyOfLoreto") is not null
                && OfferLitany is not null && await OfferLitany();
            Router.GoBack();
            if (prayLitany) Router.Navigate<Views.CustomDevotionFlowPage>(LitanyContinuation(_languageCode));
            return;
        }

        _index++;
        RenderCurrentStep();
        SaveProgress();
    }

    [RelayCommand]
    private void Back()
    {
        if (_index == 0)
        {
            return;
        }

        _index--;
        RenderCurrentStep();
        SaveProgress();
    }

    [RelayCommand]
    private void GoToPreviousMystery()
    {
        if (MysteryStepNavigation.Previous(_steps, _index) is not { } target) return;
        _index = target;
        RenderCurrentStep();
        SaveProgress();
    }

    [RelayCommand]
    private void GoToNextMystery()
    {
        if (MysteryStepNavigation.Next(_steps, _index) is not { } target) return;
        _index = target;
        RenderCurrentStep();
        SaveProgress();
    }

    private void SaveProgress()
    {
        if (string.IsNullOrEmpty(_runKey) || _steps.Count == 0) return;
        if (_index <= 0)
        {
            _runStore.Remove(_runKey);
            return;
        }

        _runStore.Save(_runKey, new PrayerRunState(
            _runSignature,
            _index,
            _chosenLanguage,
            PrayerRunState.LocalDateString(DateOnly.FromDateTime(DateTime.Now))));
    }

    private void ClearProgress()
    {
        if (!string.IsNullOrEmpty(_runKey)) _runStore.Remove(_runKey);
    }
}
