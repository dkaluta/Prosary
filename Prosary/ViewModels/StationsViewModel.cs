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
/// Drives the Stations of the Cross prayer flow — no bead progress indicator (unlike
/// <see cref="RosaryViewModel"/>), just the shared header/progress/footer chrome, matching
/// Android's <c>StationsFlowScreen.kt</c>/iOS's <c>StationsFlowView.swift</c>. Unlike the Rosary,
/// the Stations can be launched with no saved favorite at all (straight from Home) — in that case
/// it always uses the app-level default language (Stations has no per-favorite language of its
/// own; see FavoritesViewModel), and a star toggle lets the user save/unsave the one Stations
/// favorite on the fly.
/// </summary>
public partial class StationsViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly PrayerEngine _engine;
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

    /// <summary>Id of the saved Stations favorite matching the current language, if any — drives
    /// the star toggle. Null means "not favorited yet".</summary>
    [ObservableProperty]
    private Guid? _matchingFavoriteId;

    public string MysteryImageFile => PrayerPackStore.ImageFileUri(MysteryImageKey) ?? (MysteryImageKey == "cross_placeholder"
        ? "ms-appx:///Assets/Images/cross_placeholder.png"
        : $"ms-appx:///Assets/Images/{MysteryImageKey}.jpg");

    public string NextButtonText => IsLastStep ? "Finish" : "Next";

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    public bool IsFavorited => MatchingFavoriteId is not null;

    public StationsViewModel(IPresetStore presets, PrayerEngine engine, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _engine = engine;
        _calendar = calendar;
    }

    public async Task LoadAsync(Guid? prayerId)
    {
        try
        {
            // Seeds the star as already-favorited immediately, without waiting on the initial
            // favorites fetch below.
            MatchingFavoriteId = prayerId;

            _languageCode = LanguageCatalog.Resolve(LanguageCatalog.DefaultSentinel).Code;

            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            _steps = _engine.BuildSteps(new Prayer { Kind = PrayerKind.StationsOfTheCross, LanguageCode = LanguageCatalog.DefaultSentinel });
            _index = 0;
            SeasonColor = _calendar.GetSeasonColorForToday();

            RenderCurrentStep();

            var allFavorites = await _presets.GetAllAsync();
            MatchingFavoriteId = allFavorites.FirstOrDefault(p => p.Kind == PrayerKind.StationsOfTheCross)?.Id;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[StationsViewModel] Failed to load Stations session: {ex}");
            Header = "Something went wrong";
            Body = "The Stations of the Cross couldn't be loaded. Please go back and try again.";
        }
    }

    partial void OnMysteryImageKeyChanged(string value) => OnPropertyChanged(nameof(MysteryImageFile));

    partial void OnIsLastStepChanged(bool value) => OnPropertyChanged(nameof(NextButtonText));

    partial void OnSubtitleChanged(string? value) => OnPropertyChanged(nameof(HasSubtitle));

    partial void OnMatchingFavoriteIdChanged(Guid? value) => OnPropertyChanged(nameof(IsFavorited));

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
        MysteryImageKey = step.ImageOverrideKey ?? "cross_placeholder";
        ProgressText = $"{_index + 1} of {_steps.Count}";
        Progress = (_index + 1) / (double)_steps.Count;
        CanGoBack = _index > 0;
        IsLastStep = _index == _steps.Count - 1;

        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, step.IsScripture);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, step.IsScripture);
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

        var newFavorite = new Prayer
        {
            Name = PrayerKind.StationsOfTheCross.DefaultName(),
            Kind = PrayerKind.StationsOfTheCross,
            IsDefault = true,
            LanguageCode = LanguageCatalog.DefaultSentinel,
        };
        await _presets.SaveAsync(newFavorite);
        MatchingFavoriteId = newFavorite.Id;
    }
}
