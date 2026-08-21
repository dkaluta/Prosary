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
/// Drives every <see cref="PrayerKind.Custom"/> devotion's prayer flow — reads its title/steps
/// from <see cref="PrayerPackStore"/>/<see cref="PrayerEngine"/> instead of a per-devotion
/// hardcoded builder, so a new generic devotion needs no new ViewModel at all. Like the old
/// Angelus, a generic devotion can be launched with no saved favorite at all (straight from
/// Home) — in that case it always uses the app-level default language, and a star toggle lets the
/// user save/unsave the one favorite on the fly.
///
/// A decade/bead-structured ("rosary" type) devotion gets the same bead track as the Rosary
/// (<see cref="RebuildBeads"/>, absorbed from the deleted FranciscanCrownViewModel — itself
/// unchanged from <see cref="RosaryViewModel"/>); flat devotions (no step carries a DecadeIndex)
/// get none — <see cref="ShowsBeadTrack"/> drives the page's Visibility bindings.
/// </summary>
public partial class CustomDevotionViewModel : ObservableObject, IPrayerStepFlowViewModel, IAudioAwareStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly PrayerEngine _engine;
    private readonly LiturgicalCalendarService _calendar;
    private readonly IReminderScheduler _reminders;

    /// <summary>Created lazily on first successful track pick — the service captures the UI
    /// thread's DispatcherQueue, and the ViewModel is always constructed there.</summary>
    private AudioPlaybackService? _audio;
    private IReadOnlyList<string> _audioChapterTitles = [];
    /// <summary>True while <see cref="OnAudioServiceStateChanged"/> is writing the observable
    /// audio properties, so the Slider's TwoWay write-back doesn't echo every tick into a seek.</summary>
    private bool _updatingAudioFromPlayback;

    private IReadOnlyList<RosaryStep> _steps = [];
    private int _index;
    private string? _languageCode;
    private string _bundleId = string.Empty;
    private bool _hasClosingCross;
    private string? _variantId;

    /// <summary>The favorite's raw language choice: an explicit code, or the sentinel ("follow
    /// the app-level default setting"). <see cref="_languageCode"/> is always the resolved code.</summary>
    private string _chosenLanguage = LanguageCatalog.DefaultSentinel;

    [ObservableProperty]
    private string _devotionTitle = string.Empty;

    [ObservableProperty]
    private string _header = string.Empty;

    [ObservableProperty]
    private string? _subtitle;

    [ObservableProperty]
    private string _body = string.Empty;

    // The versicle/response prayer shown above a scripture body in the regular typeface.
    [ObservableProperty]
    private string _acclamation = string.Empty;

    [ObservableProperty]
    private bool _hasAcclamation;

    [ObservableProperty]
    private string _acclamationFontFamily = "Georgia";

    [ObservableProperty]
    private string _mysteryImageKey = "cross_placeholder";

    [ObservableProperty]
    private string _progressText = string.Empty;

    [ObservableProperty]
    private double? _progress;

    [ObservableProperty]
    private bool _canGoBack;

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

    /// <summary>True for a decade/bead-structured ("rosary" type) devotion — any built step
    /// carries a DecadeIndex. Drives the bead track's Visibility on the page.</summary>
    [ObservableProperty]
    private bool _showsBeadTrack;

    [ObservableProperty]
    private ObservableCollection<IReadOnlyList<BeadInfo>> _topBeadRows = [];

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

    /// <summary>See <see cref="RosaryViewModel.HasRoomForSingleMinorColumn"/> — set by the page
    /// from its own measured height.</summary>
    [ObservableProperty]
    private bool _hasRoomForSingleMinorColumn = true;

    /// <summary>See <see cref="RosaryViewModel.HasDarkTheme"/> — set by the page from its own
    /// <c>FrameworkElement.ActualTheme</c>.</summary>
    [ObservableProperty]
    private bool _hasDarkTheme;

    partial void OnHasDarkThemeChanged(bool value) => RebuildBeads();

    public IReadOnlyList<BeadInfo> BottomBeadsColumn1 => BottomBeads.Take((BottomBeads.Count + 1) / 2).ToList();

    public IReadOnlyList<BeadInfo> BottomBeadsColumn2 => BottomBeads.Skip((BottomBeads.Count + 1) / 2).ToList();

    /// <summary>Id of the saved favorite for this bundle matching the current language, if any —
    /// drives the star toggle. Null means "not favorited yet".</summary>
    [ObservableProperty]
    private Guid? _matchingFavoriteId;

    // --- Audio playback (the transport bar above the footer; hidden when the session's
    // --- devotion+language(+variant) has no narrated recording). ---

    [ObservableProperty]
    private bool _hasAudio;

    [ObservableProperty]
    private bool _isAudioPlaying;

    [ObservableProperty]
    private string _audioChapterTitle = string.Empty;

    [ObservableProperty]
    private string _audioTimeText = "0:00/0:00";

    /// <summary>Seconds; TwoWay-bound to the bar's Slider — user writes seek, playback ticks
    /// write through <see cref="_updatingAudioFromPlayback"/> without re-seeking.</summary>
    [ObservableProperty]
    private double _audioPosition;

    /// <summary>Slider Maximum — kept off 0 so an empty slider never divides by zero.</summary>
    [ObservableProperty]
    private double _audioDuration = 0.01;

    [ObservableProperty]
    private bool _canSkipAudioChapter;

    // --- Transliteration (v0.7 reading aid): swap the body for the author's other-script
    // --- rendering; sticky across steps for pray-along sessions. ---

    [ObservableProperty]
    private bool _hasTransliteration;

    [ObservableProperty]
    private bool _showsTransliteration;

    [RelayCommand]
    private void ToggleTransliteration()
    {
        ShowsTransliteration = !ShowsTransliteration;
        RenderCurrentStep();
    }

    public string MysteryImageFile => PrayerPackStore.ImageFileUri(MysteryImageKey) ?? (MysteryImageKey == "cross_placeholder"
        ? "ms-appx:///Assets/Images/cross_placeholder.png"
        : $"ms-appx:///Assets/Images/{MysteryImageKey}.jpg");

    public string NextButtonText => IsLastStep ? Loc.Tr("common_finish", "Finish") : Loc.Tr("common_next", "Next");

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    /// <summary>Whether this devotion is on Pray. The star pins; the Prayer alongside it only
    /// carries the language/variant/day, so unpinning leaves those settings intact.</summary>
    [ObservableProperty]
    private bool _isPinned;

    /// <summary>Set when a day was missed: the day that should have happened, and the one today
    /// calls for. The page shows the three-way choice while this is non-null.</summary>
    [ObservableProperty]
    private bool _showsMissedDayChoice;

    private int _missedDay;
    private int _calendarDueDay;
    private string? _suggestedNextId;

    /// <summary>Set when the last day of a series is finished and the bundle's SuggestedNext
    /// resolves to something this device actually has.</summary>
    [ObservableProperty]
    private bool _showsCompletionSuggestion;

    [ObservableProperty]
    private string _suggestedNextName = string.Empty;

    public string CompletionTitleText =>
        string.Format(Loc.Tr("multi_day_completed_title", "That completes it. Pray {0} next?"), SuggestedNextName);

    public string PrayNextText =>
        string.Format(Loc.Tr("multi_day_pray_next", "Pray {0}"), SuggestedNextName);

    public string MissedDayPrayMissedText =>
        string.Format(Loc.Tr("multi_day_pray_missed", "Pray day {0}"), _missedDay + 1);

    public string MissedDayPrayTodayText =>
        string.Format(Loc.Tr("multi_day_pray_today", "Continue with day {0}"), _calendarDueDay + 1);

    /// <summary>The bundle's alternate step-sets (e.g. the Stations' traditional vs. scriptural
    /// forms); empty for single-form devotions. The page builds its variant flyout from this.</summary>
    public IReadOnlyList<CustomDevotionDefinition.Variant> Variants { get; private set; } = [];

    public bool ShowsVariantMenu => Variants.Count > 1;

    /// <summary>Multi-day devotions: every authored day; empty for single-session types. The
    /// page builds its day flyout from this.</summary>
    public IReadOnlyList<CustomDevotionDefinition.Day> Days { get; private set; } = [];

    public bool ShowsDayMenu => Days.Count > 1;

    /// <summary>The day this session prays (0-based; sourced from the favorite).</summary>
    public int CurrentDayIndex { get; private set; }

    /// <summary>Jump to a day: rebuilds from step 0 and persists to the matching favorite.</summary>
    public async Task SelectDayAsync(int dayIndex)
    {
        CurrentDayIndex = dayIndex;
        _steps = _engine.BuildSteps(new Prayer
        {
            Kind = PrayerKind.Custom,
            LanguageCode = _chosenLanguage,
            CustomDevotionId = _bundleId,
            VariantId = _variantId,
            DayIndex = dayIndex,
        });
        _index = 0;
        RenderCurrentStep();
        PickAudioTrack();
        await PersistDayIndexAsync(dayIndex);
    }

    private async Task PersistDayIndexAsync(int dayIndex)
    {
        if (MatchingFavoriteId is { } id && await _presets.GetAsync(id) is { } favorite)
        {
            await _presets.SaveAsync(favorite with { DayIndex = dayIndex });
        }
    }

    /// <summary>"No explicit choice" resolves per the prayer language (a rite can declare a
    /// form its own), so the flyout checkmark and the persistence baseline both use the
    /// effective default rather than blindly the first variant.</summary>
    private string? DefaultVariantId =>
        PrayerPackStore.Definition(_bundleId)?.EffectiveVariantId(null, _languageCode)
        ?? (Variants.Count > 0 ? Variants[0].Id : null);

    public string? CurrentVariantId => _variantId ?? DefaultVariantId;

    /// <summary>The bundle's languages (manifest order); the page builds its language flyout
    /// from this. The app-level setting was the only way to change a generic devotion's language
    /// and testers didn't find it — they assumed the devotion shipped fewer languages than it
    /// does.</summary>
    public IReadOnlyList<LanguageOption> Languages { get; private set; } = [];

    public bool ShowsLanguageMenu => Languages.Count > 1;

    /// <summary>What the flyout's checkmark matches: an explicit code, or the sentinel for
    /// "App setting".</summary>
    public string CurrentLanguageRaw => _chosenLanguage;

    /// <summary>Switches the session's language in place, keeping the current position — unlike
    /// a variant switch, the step sequence is identical across languages, only its text changes.
    /// Persists to the matching favorite when one exists.</summary>
    public async Task SelectLanguageAsync(string raw)
    {
        _chosenLanguage = raw;
        _languageCode = PrayerPackStore.EffectiveLanguage(_bundleId, raw);
        IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
        OnPropertyChanged(nameof(CurrentLanguageRaw));
        // The language can carry its own default form (a rite's native variant), so the
        // effective variant — and with it the closing cross — can change with the language.
        OnPropertyChanged(nameof(CurrentVariantId));
        if (PrayerPackStore.Definition(_bundleId) is { } switchedDefinition)
        {
            _hasClosingCross = switchedDefinition
                .ResolvedRosary(switchedDefinition.EffectiveVariantId(_variantId, _languageCode))
                .HasClosingCross;
        }

        var position = _index;
        _steps = _engine.BuildSteps(new Prayer
        {
            Kind = PrayerKind.Custom,
            LanguageCode = raw,
            CustomDevotionId = _bundleId,
            VariantId = _variantId,
            DayIndex = CurrentDayIndex,
        });
        _index = Math.Clamp(position, 0, Math.Max(_steps.Count - 1, 0));
        RenderCurrentStep();
        PickAudioTrack();

        if (MatchingFavoriteId is { } id && await _presets.GetAsync(id) is { } favorite)
        {
            await _presets.SaveAsync(favorite with { LanguageCode = raw });
        }
    }

    /// <summary>Switches the session to another variant: rebuilds from step 0 and persists the
    /// choice to the matching favorite when one exists.</summary>
    public async Task SelectVariantAsync(string variantId)
    {
        _variantId = variantId == DefaultVariantId ? null : variantId;
        OnPropertyChanged(nameof(CurrentVariantId));

        // Rosary-type forms can differ in whether they end with the cross, so the bead track's
        // closing bead has to follow the switch too.
        var definition = PrayerPackStore.Definition(_bundleId);
        _hasClosingCross = definition?
            .ResolvedRosary(definition.EffectiveVariantId(_variantId, _languageCode))
            .HasClosingCross ?? false;

        _steps = _engine.BuildSteps(new Prayer
        {
            Kind = PrayerKind.Custom,
            LanguageCode = _chosenLanguage,
            CustomDevotionId = _bundleId,
            VariantId = _variantId,
            DayIndex = CurrentDayIndex,
        });
        _index = 0;
        RenderCurrentStep();
        PickAudioTrack();

        if (MatchingFavoriteId is { } id && await _presets.GetAsync(id) is { } favorite)
        {
            await _presets.SaveAsync(favorite with { VariantId = _variantId });
        }
    }

    public CustomDevotionViewModel(
        IPresetStore presets,
        PrayerEngine engine,
        LiturgicalCalendarService calendar,
        IReminderScheduler reminders)
    {
        _presets = presets;
        _engine = engine;
        _calendar = calendar;
        _reminders = reminders;
    }

    public async Task LoadAsync(Guid? prayerId, string bundleId)
    {
        try
        {
            _bundleId = bundleId;
            DevotionTitle = PrayerPackStore.Info(bundleId)?.LocalizedDisplayName ?? bundleId;
            var definition = PrayerPackStore.Definition(bundleId);
            Variants = definition?.Variants ?? [];
            OnPropertyChanged(nameof(ShowsVariantMenu));
            Days = definition?.Days ?? [];
            OnPropertyChanged(nameof(ShowsDayMenu));

            // Seeds the star as already-favorited immediately, without waiting on the initial
            // favorites fetch below.
            MatchingFavoriteId = prayerId;

            var all = await _presets.GetAllAsync();
            var favorite = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId);
            MatchingFavoriteId ??= favorite?.Id;
            _variantId = favorite?.VariantId;
            OnPropertyChanged(nameof(CurrentVariantId));

            // Per form, not per bundle: one recension of a chaplet can end with the cross where
            // another does not, and the bead track draws a closing bead on the strength of this.
            // Computed here rather than beside the definition lookup because it depends on the
            // variant the favorite chose — and, absent one, on the language's own default form —
            // both of which are only known now (_languageCode itself is resolved further down).
            _hasClosingCross = definition?
                .ResolvedRosary(definition.EffectiveVariantId(
                    _variantId, PrayerPackStore.EffectiveLanguage(bundleId, favorite?.LanguageCode)))
                .HasClosingCross ?? false;

            // The favorite carries the language to pray in (sentinel = the app default).
            _chosenLanguage = favorite?.LanguageCode ?? LanguageCatalog.DefaultSentinel;
            CurrentDayIndex = favorite?.DayIndex ?? 0;
            IsPinned = FavoriteDevotions.Contains(bundleId, ImpliedPinnedIds(all));

            // A series decides its own day: today's if it is unprayed, the same day again if it
            // was already prayed today, and a choice when one was missed.
            if (Days.Count > 1 && (definition?.DayProgression ?? "series") == "series")
            {
                var run = MultiDayRuns.Run(bundleId);
                switch (run?.GetResumption(Days.Count) ?? new MultiDayRun.Resumption.Start())
                {
                    case MultiDayRun.Resumption.Start _:
                        CurrentDayIndex = 0;
                        break;
                    case MultiDayRun.Resumption.Resume resume:
                        CurrentDayIndex = resume.Day;
                        break;
                    case MultiDayRun.Resumption.Choose choose:
                        CurrentDayIndex = choose.Missed;
                        _missedDay = choose.Missed;
                        _calendarDueDay = choose.Next;
                        OnPropertyChanged(nameof(MissedDayPrayMissedText));
                        OnPropertyChanged(nameof(MissedDayPrayTodayText));
                        ShowsMissedDayChoice = true;
                        break;
                    case MultiDayRun.Resumption.Complete _:
                        CurrentDayIndex = Days.Count - 1;
                        break;
                }

                // Praying twice in one day re-prays that day rather than eating tomorrow's.
                if (run is not null && run.HasPrayedToday() && run.PrayedDays.Count > 0)
                {
                    CurrentDayIndex = run.PrayedDays[^1];
                }
            }
            _languageCode = PrayerPackStore.EffectiveLanguage(bundleId, _chosenLanguage);
            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            // A language prayed in more than one use lists those under it — the rite is a second
            // question, and one whose gaps fall back to the language's own wording.
            var languages = (PrayerPackStore.Info(bundleId)?.Languages ?? [])
                .Select(code => LanguageCatalog.All.FirstOrDefault(l => l.Code == code))
                .OfType<LanguageOption>()
                .ToList();
            var rites = LanguageCatalog.Rites(LanguageCatalog.Resolve(_chosenLanguage).Code);
            if (rites.Count > 1)
            {
                languages.AddRange(rites);
            }

            Languages = languages;
            OnPropertyChanged(nameof(ShowsLanguageMenu));
            OnPropertyChanged(nameof(CurrentLanguageRaw));

            _steps = _engine.BuildSteps(new Prayer
            {
                Kind = PrayerKind.Custom,
                LanguageCode = _chosenLanguage,
                CustomDevotionId = bundleId,
                VariantId = _variantId,
                DayIndex = CurrentDayIndex,
            });
            _index = 0;
            ShowsBeadTrack = _steps.Any(s => s.DecadeIndex.HasValue);
            SeasonColor = _calendar.GetSeasonColorForToday();

            RenderCurrentStep();
            PickAudioTrack();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[CustomDevotionViewModel] Failed to load devotion '{bundleId}': {ex}");
            Header = Loc.Tr("flow_error_header", "Something went wrong");
            Body = Loc.Tr("flow_error_body", "This devotion couldn't be loaded. Please go back and try again.");
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

    private void RenderCurrentStep()
    {
        if (_steps.Count == 0)
        {
            return;
        }

        var step = _steps[_index];
        Header = step.Title;
        Subtitle = step.Subtitle;
        HasTransliteration = step.TransliteratedBody is not null;
        Body = ShowsTransliteration && step.TransliteratedBody is { } transliterated
            ? transliterated
            : step.Body;
        Acclamation = step.Acclamation ?? string.Empty;
        HasAcclamation = step.Acclamation is not null;
        MysteryImageKey = step.ImageVariantKey ?? step.Mystery?.ImageKey ?? step.ImageOverrideKey ?? "cross_placeholder";
        ProgressText = string.Format(Loc.Tr("flow_step_of", "{0} of {1}"), _index + 1, _steps.Count);
        Progress = (_index + 1) / (double)_steps.Count;
        CanGoBack = _index > 0;
        IsLastStep = _index == _steps.Count - 1;

        // A transliteration is in a different script from its language's own, so the face has to
        // follow the text rather than the language — otherwise Syriac letters are drawn with a
        // Hebrew face that has no glyphs for them, and the toggle shows a row of tofu.
        var bodyScript = ShowsTransliteration && step.TransliteratedBody is { } shown
            ? PrayerTypography.ScriptOf(shown)
            : (PrayerTypography.Script?)null;
        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, step.IsScripture, bodyScript);
        AcclamationFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, isScripture: false);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, step.IsScripture, bodyScript);

        RebuildBeads();
    }

    private void RebuildBeads()
    {
        if (!ShowsBeadTrack)
        {
            return;
        }

        var layout = BeadLayout.Build(_steps, _index, _hasClosingCross, HasDarkTheme);

        TopBeadRows = new ObservableCollection<IReadOnlyList<BeadInfo>>(layout.TopRows);
        OpeningCross = layout.OpeningCross;
        GroupColumns = new ObservableCollection<BeadColumn>(layout.GroupColumns);
        AntiphonBead = layout.Antiphon;
        ClosingCross = layout.ClosingCross;
        BottomBeads = new ObservableCollection<BeadInfo>(layout.BottomBeads);
        ShowBottomBeads = layout.ShowBottomBeads;
    }

    [RelayCommand]
    private void Next()
    {
        if (IsLastStep)
        {
            // Finishing a multi-day session advances the favorite to the next day (staying on
            // the last once complete) — tomorrow opens where the novena left off.
            if (Days.Count > 1)
            {
                // A series advances by calendar day, so record *which* day was prayed and let
                // the run decide what comes next — praying twice today must not skip tomorrow's.
                if ((PrayerPackStore.Definition(_bundleId)?.DayProgression ?? "series") == "series")
                {
                    MultiDayRuns.RecordPrayed(_bundleId, CurrentDayIndex);
                    // The remaining days keep their prompts; the finished ones lose theirs.
                    _reminders.RefreshSeries(_bundleId);

                    // The last day earns the bundle's parting suggestion — but only when it
                    // names a devotion this device has, so a hand-written series can point at
                    // its author's other work without leaving a dead end elsewhere.
                    if (MultiDayRuns.Run(_bundleId)?.IsComplete(Days.Count) == true &&
                        MultiDayStatus.SuggestedNext(_bundleId) is { } suggestion)
                    {
                        _ = PersistDayIndexAsync(Math.Min(CurrentDayIndex + 1, Days.Count - 1));
                        _suggestedNextId = suggestion.Id;
                        SuggestedNextName = suggestion.Name;
                        ShowsCompletionSuggestion = true;
                        StopAudio();
                        return;
                    }
                }

                _ = PersistDayIndexAsync(Math.Min(CurrentDayIndex + 1, Days.Count - 1));
            }

            StopAudio();
            Router.GoBack();
            return;
        }

        _index++;
        RenderCurrentStep();
        AlignAudioToCurrentStep();
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
        AlignAudioToCurrentStep();
    }

    // --- Audio playback wiring (mirrors iOS's CustomDevotionFlowView / Android's
    // --- CustomDevotionFlowScreen; the service holds the MediaPlayer, this holds the bindables). ---

    /// <summary>The recording for this session, if the bundle ships one: language must match,
    /// and the track's variant (null = the bundle's single/default form) must match the
    /// session's. First declared match wins — audio.json order is the author's preference
    /// order.</summary>
    private void PickAudioTrack()
    {
        var defaultVariantId = DefaultVariantId;
        var effectiveVariant = _variantId ?? defaultVariantId;
        var match = PrayerPackStore.AudioTracks(_bundleId)
            .FirstOrDefault(t => t.Language == _languageCode && (t.VariantId ?? defaultVariantId) == effectiveVariant);
        if (match is null)
        {
            StopAudio();
            return;
        }

        if (_audio?.Track?.Id == match.Id && _audio.IsLoaded)
        {
            return;
        }

        if (_audio is null)
        {
            _audio = new AudioPlaybackService();
            _audio.StateChanged += OnAudioServiceStateChanged;
        }

        // titleKey resolves through the same per-bundle content chain as step text (the track's
        // own language, not the UI language).
        _audioChapterTitles = (match.Chapters ?? [])
            .Select(c => c.Title
                ?? (c.TitleKey is { } key ? PrayerPackStore.ResolveBodyText(_bundleId, match.Language, key) : string.Empty))
            .ToList();
        _audio.Load(_bundleId, match);
        AlignAudioToCurrentStep();
    }

    /// <summary>After a manual Back/Next (or a fresh load), bring the recording to the chapter
    /// that narrates the current step — when one does; steps between chapter hints leave the
    /// audio where it is.</summary>
    private void AlignAudioToCurrentStep()
    {
        if (_audio is not { IsLoaded: true } audio || audio.Track?.Chapters is not { } chapters)
        {
            return;
        }

        var target = chapters.ToList().FindIndex(c => c.StepIndex == _index);
        if (target >= 0 && audio.CurrentChapterIndex != target)
        {
            audio.SeekToChapter(target);
        }
    }

    /// <summary>Copies the service's state into the bindables, and lets the recording's
    /// chapters drive the text: entering a chapter that carries a StepIndex hint turns the
    /// page. Hints are advisory (the built sequence is option- and calendar-dependent), so
    /// out-of-range ones are ignored rather than trusted.</summary>
    private void OnAudioServiceStateChanged()
    {
        if (_audio is not { } audio)
        {
            return;
        }

        _updatingAudioFromPlayback = true;
        try
        {
            HasAudio = audio.IsLoaded;
            IsAudioPlaying = audio.IsPlaying;
            AudioPosition = audio.CurrentTime;
            AudioDuration = Math.Max(audio.Duration, 0.01);
            AudioTimeText = $"{Timestamp(audio.CurrentTime)}/{Timestamp(audio.Duration)}";
            var chapterCount = audio.Track?.Chapters?.Count ?? 0;
            CanSkipAudioChapter = chapterCount > 1;
            if (audio.CurrentChapterIndex is { } chapterIndex)
            {
                AudioChapterTitle = chapterIndex < _audioChapterTitles.Count ? _audioChapterTitles[chapterIndex] : string.Empty;
                if (audio.Track?.Chapters?[chapterIndex].StepIndex is { } hint
                    && hint >= 0 && hint < _steps.Count && hint != _index)
                {
                    _index = hint;
                    RenderCurrentStep();
                }
            }
            else
            {
                AudioChapterTitle = string.Empty;
            }
        }
        finally
        {
            _updatingAudioFromPlayback = false;
        }
    }

    partial void OnAudioPositionChanged(double value)
    {
        // The playback-tick echo is suppressed by the flag; the distance threshold keeps a
        // drag from storming the (asynchronous) MediaPlayer with a seek per thumb-pixel and
        // ignores the session's own sub-tick jitter writing back through the TwoWay binding.
        if (!_updatingAudioFromPlayback && _audio is { } audio && Math.Abs(value - audio.CurrentTime) > 0.25)
        {
            audio.Seek(value);
        }
    }

    [RelayCommand]
    private void AudioPlayPause() => _audio?.PlayPause();

    [RelayCommand]
    private void AudioPreviousChapter() => _audio?.PreviousChapter();

    [RelayCommand]
    private void AudioNextChapter() => _audio?.NextChapter();

    /// <summary>Page calls this on navigate-away; also runs when a language/variant switch
    /// finds no matching recording.</summary>
    public void StopAudio()
    {
        if (_audio is { } audio)
        {
            audio.StateChanged -= OnAudioServiceStateChanged;
            audio.Dispose();
            _audio = null;
        }

        _audioChapterTitles = [];
        HasAudio = false;
        IsAudioPlaying = false;
        AudioChapterTitle = string.Empty;
        AudioTimeText = "0:00/0:00";
        AudioPosition = 0;
        AudioDuration = 0.01;
        CanSkipAudioChapter = false;
    }

    private static string Timestamp(double seconds)
    {
        var whole = (int)seconds;
        return $"{whole / 60}:{whole % 60:D2}";
    }

    /// <summary>A devotion counts as pinned by default when it already has a saved configuration
    /// — the same fallback the Pray page uses, so the star agrees with what that page shows.</summary>
    private static List<string> ImpliedPinnedIds(IEnumerable<Prayer> all) =>
        all.Select(prayer => prayer.Kind switch
        {
            PrayerKind.Rosary => "rosary",
            PrayerKind.JesusPrayer => "jesusPrayer",
            _ => prayer.CustomDevotionId,
        }).OfType<string>().ToList();

    [RelayCommand]
    private async Task ToggleFavoriteAsync()
    {
        // Pinning is what puts a devotion on Pray; unpinning keeps the Prayer, which holds the
        // language, variant and day for next time.
        var implied = ImpliedPinnedIds(await _presets.GetAllAsync());
        FavoriteDevotions.Toggle(_bundleId, implied);
        IsPinned = FavoriteDevotions.Contains(_bundleId, implied);

        if (IsPinned && MatchingFavoriteId is null)
        {
            var newFavorite = new Prayer
            {
                Name = DevotionTitle,
                Kind = PrayerKind.Custom,
                IsDefault = true,
                LanguageCode = LanguageCatalog.DefaultSentinel,
                CustomDevotionId = _bundleId,
            };
            await _presets.SaveAsync(newFavorite);
            MatchingFavoriteId = newFavorite.Id;
        }
    }

    /// <summary>A missed day is a real choice, not an error: take the day that should have
    /// happened, stay with the calendar, or start the run over.</summary>
    [RelayCommand]
    private async Task PrayMissedDayAsync()
    {
        ShowsMissedDayChoice = false;
        await SelectDayAsync(_missedDay);
    }

    [RelayCommand]
    private async Task PrayCalendarDayAsync()
    {
        ShowsMissedDayChoice = false;
        await SelectDayAsync(_calendarDueDay);
    }

    partial void OnSuggestedNextNameChanged(string value)
    {
        OnPropertyChanged(nameof(CompletionTitleText));
        OnPropertyChanged(nameof(PrayNextText));
    }

    /// <summary>Hands over to the devotion the finished series suggests.</summary>
    [RelayCommand]
    private void PraySuggestedNext()
    {
        ShowsCompletionSuggestion = false;
        if (_suggestedNextId is { } next)
        {
            Router.GoBack();
            Router.Navigate<Views.CustomDevotionFlowPage>(new CustomDevotionFlowParams(null, next));
            return;
        }

        Router.GoBack();
    }

    [RelayCommand]
    private void DismissCompletionSuggestion()
    {
        ShowsCompletionSuggestion = false;
        Router.GoBack();
    }

    [RelayCommand]
    private async Task StartRunOverAsync()
    {
        ShowsMissedDayChoice = false;
        MultiDayRuns.StartFresh(_bundleId);
        _reminders.RefreshSeries(_bundleId);
        await SelectDayAsync(0);
    }
}
