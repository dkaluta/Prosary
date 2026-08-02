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

    public string MysteryImageFile => PrayerPackStore.ImageFileUri(MysteryImageKey) ?? (MysteryImageKey == "cross_placeholder"
        ? "ms-appx:///Assets/Images/cross_placeholder.png"
        : $"ms-appx:///Assets/Images/{MysteryImageKey}.jpg");

    public string NextButtonText => IsLastStep ? "Finish" : "Next";

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    public bool IsFavorited => MatchingFavoriteId is not null;

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

    public string? CurrentVariantId => _variantId ?? (Variants.Count > 0 ? Variants[0].Id : null);

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
        var resolved = LanguageCatalog.Resolve(raw);
        _languageCode = resolved.Code;
        IsRightToLeft = resolved.IsRightToLeft;
        OnPropertyChanged(nameof(CurrentLanguageRaw));

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
        var defaultId = Variants.Count > 0 ? Variants[0].Id : null;
        _variantId = variantId == defaultId ? null : variantId;
        OnPropertyChanged(nameof(CurrentVariantId));

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

    public CustomDevotionViewModel(IPresetStore presets, PrayerEngine engine, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _engine = engine;
        _calendar = calendar;
    }

    public async Task LoadAsync(Guid? prayerId, string bundleId)
    {
        try
        {
            _bundleId = bundleId;
            DevotionTitle = PrayerPackStore.Info(bundleId)?.LocalizedDisplayName ?? bundleId;
            var definition = PrayerPackStore.Definition(bundleId);
            _hasClosingCross = definition?.HasClosingCross ?? false;
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

            // The favorite carries the language to pray in (sentinel = the app default).
            _chosenLanguage = favorite?.LanguageCode ?? LanguageCatalog.DefaultSentinel;
            CurrentDayIndex = favorite?.DayIndex ?? 0;
            var resolvedLanguage = LanguageCatalog.Resolve(_chosenLanguage);
            _languageCode = resolvedLanguage.Code;
            IsRightToLeft = resolvedLanguage.IsRightToLeft;
            Languages = (PrayerPackStore.Info(bundleId)?.Languages ?? [])
                .Select(code => LanguageCatalog.All.FirstOrDefault(l => l.Code == code))
                .OfType<LanguageOption>()
                .ToList();
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
            Header = "Something went wrong";
            Body = "This devotion couldn't be loaded. Please go back and try again.";
        }
    }

    partial void OnMysteryImageKeyChanged(string value) => OnPropertyChanged(nameof(MysteryImageFile));

    partial void OnIsLastStepChanged(bool value) => OnPropertyChanged(nameof(NextButtonText));

    partial void OnSubtitleChanged(string? value) => OnPropertyChanged(nameof(HasSubtitle));

    partial void OnMatchingFavoriteIdChanged(Guid? value) => OnPropertyChanged(nameof(IsFavorited));

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
        Body = step.Body;
        Acclamation = step.Acclamation ?? string.Empty;
        HasAcclamation = step.Acclamation is not null;
        MysteryImageKey = step.Mystery?.ImageKey ?? step.ImageOverrideKey ?? "cross_placeholder";
        ProgressText = $"{_index + 1} of {_steps.Count}";
        Progress = (_index + 1) / (double)_steps.Count;
        CanGoBack = _index > 0;
        IsLastStep = _index == _steps.Count - 1;

        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, step.IsScripture);
        AcclamationFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, isScripture: false);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, step.IsScripture);

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
        var defaultVariantId = Variants.Count > 0 ? Variants[0].Id : null;
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

    [RelayCommand]
    private async Task ToggleFavoriteAsync()
    {
        if (MatchingFavoriteId is { } id)
        {
            var existing = await _presets.GetAsync(id);
            if (existing is not null)
            {
                await _presets.DeleteAsync(existing);
            }

            MatchingFavoriteId = null;
            return;
        }

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
