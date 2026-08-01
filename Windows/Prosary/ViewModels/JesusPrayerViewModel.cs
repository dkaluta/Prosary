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
/// Drives the Jesus Prayer flow — ported from Android's <c>JesusPrayerFlowScreen.kt</c>. Unlike
/// the Rosary/Angelus, there's no engine building a list of steps: every repetition prays the
/// same fixed line, so a single synthesized line of text plus a <see cref="JesusPrayerProgress"/>
/// counter (<see cref="RepetitionState"/>) is the whole model. Implements
/// <see cref="IPrayerStepFlowViewModel"/> like <see cref="RosaryViewModel"/>/
/// <see cref="CustomDevotionViewModel"/> so the shared flow chrome control can bind to it the same way.
///
/// <see cref="Finish"/> and <see cref="Back"/> are deliberately distinct: this page sits two
/// levels deep in the nav stack when reached fresh (Home → Setup → Flow), so a plain back-arrow
/// pop correctly returns to Setup, but finishing a session should return all the way to Home —
/// <see cref="Finish"/> uses <see cref="Router.PopToRoot"/>. When launched from a saved favorite
/// instead (one nav level), both land in the same place.
/// </summary>
public partial class JesusPrayerViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly LiturgicalCalendarService _calendar;

    private JesusPrayerTarget _effectiveTarget = new JesusPrayerTarget.Count(33);
    private string? _languageCode;
    private bool _hasLoaded;

    [ObservableProperty]
    private JesusPrayerProgress _repetitionState = new(new JesusPrayerTarget.Count(33));

    [ObservableProperty]
    private string _header = "Jesus Prayer";

    [ObservableProperty]
    private string _body = string.Empty;

    [ObservableProperty]
    private string _mysteryImageFile = "ms-appx:///Assets/Images/christ_pantocrator.jpg";

    [ObservableProperty]
    private string _progressText = string.Empty;

    [ObservableProperty]
    private double? _progress;

    [ObservableProperty]
    private bool _isRightToLeft;

    [ObservableProperty]
    private Color _seasonColor = Color.FromArgb(0, 0, 0, 0);

    [ObservableProperty]
    private string _bodyFontFamily = "Cambria";

    [ObservableProperty]
    private double _bodyFontSize = 18;

    /// <summary>The footer's "Finish" text button is the only way to end an unbounded session
    /// (the Next button never turns into Finish — see <see cref="JesusPrayerProgress.IsLastRep"/>).</summary>
    [ObservableProperty]
    private bool _isUnbounded;

    [ObservableProperty]
    private Guid? _matchingFavoriteId;

    public string? Subtitle => null;

    public bool HasSubtitle => false;

    public bool CanGoBack => RepetitionState.CanGoBack;

    public string NextButtonText => RepetitionState.IsLastRep ? "Finish" : "Next";

    public bool IsLastStep => RepetitionState.IsLastRep;

    public bool IsFavorited => MatchingFavoriteId is not null;

    public JesusPrayerViewModel(IPresetStore presets, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _calendar = calendar;
    }

    public async Task LoadAsync(Guid? prayerId, JesusPrayerTarget? target)
    {
        try
        {
            var prayer = prayerId is { } id ? await _presets.GetAsync(id) : null;
            _effectiveTarget = prayer?.JesusPrayer.Target ?? target ?? new JesusPrayerTarget.Count(33);
            IsUnbounded = _effectiveTarget is JesusPrayerTarget.Unbounded;

            _languageCode = prayer is not null
                ? prayer.ResolvedLanguageCode
                : await ResolveDefaultLanguageAsync();

            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            SeasonColor = _calendar.GetSeasonColorForToday();
            _hasLoaded = true;
            RepetitionState = new JesusPrayerProgress(_effectiveTarget);

            var all = await _presets.GetAllAsync();
            var resolved = _languageCode ?? LanguageCatalog.DefaultCode;
            MatchingFavoriteId = all.FirstOrDefault(p =>
                p.Kind == PrayerKind.JesusPrayer && p.ResolvedLanguageCode == resolved && p.JesusPrayer.Target == _effectiveTarget)?.Id;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[JesusPrayerViewModel] Failed to load Jesus Prayer session: {ex}");
            Body = "The Jesus Prayer couldn't be loaded. Please go back and try again.";
        }
    }

    private async Task<string?> ResolveDefaultLanguageAsync()
    {
        var all = await _presets.GetAllAsync();
        var defaultJesusPrayer = all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer);
        // No favorite yet: the app-level default language, never a silent Latin fallback.
        return defaultJesusPrayer?.ResolvedLanguageCode
            ?? LanguageCatalog.Resolve(LanguageCatalog.DefaultSentinel).Code;
    }

    partial void OnRepetitionStateChanged(JesusPrayerProgress value)
    {
        OnPropertyChanged(nameof(CanGoBack));
        OnPropertyChanged(nameof(NextButtonText));
        OnPropertyChanged(nameof(IsLastStep));
        RenderCurrentStep();
    }

    partial void OnMatchingFavoriteIdChanged(Guid? value) => OnPropertyChanged(nameof(IsFavorited));

    private void RenderCurrentStep()
    {
        if (!_hasLoaded)
        {
            return;
        }

        Body = PrayerTranslations.Get(_languageCode, PrayerKey.OratioIesu);
        ProgressText = RepetitionState.TargetCount is { } count
            ? $"{RepetitionState.CurrentIndex + 1} of {count}"
            : $"{RepetitionState.CurrentIndex + 1}";
        Progress = RepetitionState.ProgressFraction;
        BodyFontFamily = PrayerTypography.ResolveBodyFontFamily(_languageCode, isScripture: false);
        BodyFontSize = PrayerTypography.ResolveBodyFontSize(_languageCode, isScripture: false);
    }

    [RelayCommand]
    private void Next()
    {
        if (RepetitionState.IsLastRep)
        {
            Router.PopToRoot();
            return;
        }

        RepetitionState = RepetitionState.GoNext();
    }

    [RelayCommand]
    private void Back() => RepetitionState = RepetitionState.GoBack();

    [RelayCommand]
    private void Finish() => Router.PopToRoot();

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
        var targetLabel = _effectiveTarget switch
        {
            JesusPrayerTarget.Count(var n) => $"× {n}",
            JesusPrayerTarget.Unbounded => "Unbounded",
            _ => throw new ArgumentOutOfRangeException()
        };
        var all = await _presets.GetAllAsync();
        var isFirst = all.All(p => p.Kind != PrayerKind.JesusPrayer);

        var newFavorite = new Prayer
        {
            Name = $"Jesus Prayer {targetLabel} ({langName})",
            Kind = PrayerKind.JesusPrayer,
            IsDefault = isFirst,
            LanguageCode = resolved,
            JesusPrayer = new JesusPrayerOptions { Target = _effectiveTarget },
        };
        await _presets.SaveAsync(newFavorite);
        MatchingFavoriteId = newFavorite.Id;
    }
}
