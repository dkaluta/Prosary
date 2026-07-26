using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Microsoft.UI;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the Seven Sorrows prayer flow. Combines <see cref="AngelusViewModel"/>'s "launchable
/// with no saved favorite" pattern (no options beyond language, so there's nothing to configure
/// before starting) with <see cref="RosaryViewModel"/>'s bead-row building
/// (<see cref="RebuildBeads"/>, unchanged from that class) — the Seven Sorrows is decade-based,
/// unlike the Angelus/Stations of the Cross. Duplicated from RosaryViewModel/
/// FranciscanCrownViewModel rather than shared through a common base/control, same reasoning as
/// FranciscanCrownViewModel's own doc comment: <c>RosaryPrayerPage.xaml</c> is itself a bespoke,
/// non-shared page, so there's no existing shared bead-track abstraction to hook into on this
/// platform. <see cref="DivineMercyViewModel"/> now duplicates this same pattern as a 4th
/// consumer — see its own doc comment for why extraction is deferred rather than done there.
/// </summary>
public partial class SevenSorrowsViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly SevenSorrowsEngine _engine;
    private readonly LiturgicalCalendarService _calendar;

    private IReadOnlyList<RosaryStep> _steps = [];
    private int _index;
    private string? _languageCode;

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

    /// <summary>Id of the saved Seven Sorrows favorite matching the current language, if any —
    /// drives the star toggle. Null means "not favorited yet".</summary>
    [ObservableProperty]
    private Guid? _matchingFavoriteId;

    public string MysteryImageFile => MysteryImageKey == "cross_placeholder"
        ? "ms-appx:///Assets/Images/cross_placeholder.png"
        : $"ms-appx:///Assets/Images/{MysteryImageKey}.jpg";

    public string NextButtonText => IsLastStep ? "Finish" : "Next";

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    public bool IsFavorited => MatchingFavoriteId is not null;

    public SevenSorrowsViewModel(IPresetStore presets, SevenSorrowsEngine engine, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _engine = engine;
        _calendar = calendar;
    }

    public async Task LoadAsync(Guid? prayerId)
    {
        try
        {
            var prayer = prayerId is { } id ? await _presets.GetAsync(id) : null;

            if (prayer is not null)
            {
                _languageCode = prayer.ResolvedLanguageCode;
            }
            else
            {
                var all = await _presets.GetAllAsync();
                var defaultSevenSorrows = all.FirstOrDefault(p => p.Kind == PrayerKind.SevenSorrows && p.IsDefault)
                    ?? all.FirstOrDefault(p => p.Kind == PrayerKind.SevenSorrows);
                _languageCode = defaultSevenSorrows?.ResolvedLanguageCode;
            }

            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            _steps = _engine.BuildSteps(_languageCode);
            _index = 0;
            SeasonColor = _calendar.GetSeasonColorForToday();

            RenderCurrentStep();

            var allFavorites = await _presets.GetAllAsync();
            var resolved = _languageCode ?? LanguageCatalog.DefaultCode;
            MatchingFavoriteId = allFavorites.FirstOrDefault(p => p.Kind == PrayerKind.SevenSorrows && p.ResolvedLanguageCode == resolved)?.Id;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[SevenSorrowsViewModel] Failed to load Seven Sorrows session: {ex}");
            Header = "Something went wrong";
            Body = "The Seven Sorrows couldn't be loaded. Please go back and try again.";
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
        MysteryImageKey = step.Mystery?.ImageKey ?? step.ImageOverrideKey ?? "cross_placeholder";
        ProgressText = $"{_index + 1} of {_steps.Count}";
        Progress = (_index + 1) / (double)_steps.Count;
        CanGoBack = _index > 0;
        IsLastStep = _index == _steps.Count - 1;

        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, step.IsScripture);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, step.IsScripture);

        RebuildBeads();
    }

    private void RebuildBeads()
    {
        var layout = BeadLayout.Build(_steps, _index, hasClosingCross: true, HasDarkTheme);

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
            Router.GoBack();
            return;
        }

        _index++;
        RenderCurrentStep();
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

        var resolved = _languageCode ?? LanguageCatalog.DefaultCode;
        var langName = LanguageCatalog.All.FirstOrDefault(l => l.Code == resolved)?.NativeName ?? resolved;
        var all = await _presets.GetAllAsync();
        var isFirst = all.All(p => p.Kind != PrayerKind.SevenSorrows);

        var newFavorite = new Prayer
        {
            Name = $"Seven Sorrows ({langName})",
            Kind = PrayerKind.SevenSorrows,
            IsDefault = isFirst,
            LanguageCode = resolved,
        };
        await _presets.SaveAsync(newFavorite);
        MatchingFavoriteId = newFavorite.Id;
    }
}
