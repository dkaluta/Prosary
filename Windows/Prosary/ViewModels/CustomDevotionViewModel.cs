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
public partial class CustomDevotionViewModel : ObservableObject, IPrayerStepFlowViewModel
{
    private readonly IPresetStore _presets;
    private readonly PrayerEngine _engine;
    private readonly LiturgicalCalendarService _calendar;

    private IReadOnlyList<RosaryStep> _steps = [];
    private int _index;
    private string? _languageCode;
    private string _bundleId = string.Empty;
    private bool _hasClosingCross;
    private string? _variantId;

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

    public string? CurrentVariantId => _variantId ?? (Variants.Count > 0 ? Variants[0].Id : null);

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
            LanguageCode = _languageCode,
            CustomDevotionId = _bundleId,
            VariantId = _variantId,
        });
        _index = 0;
        RenderCurrentStep();

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

            // Seeds the star as already-favorited immediately, without waiting on the initial
            // favorites fetch below.
            MatchingFavoriteId = prayerId;

            _languageCode = LanguageCatalog.Resolve(LanguageCatalog.DefaultSentinel).Code;

            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            var all = await _presets.GetAllAsync();
            var favorite = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId);
            MatchingFavoriteId ??= favorite?.Id;
            _variantId = favorite?.VariantId;
            OnPropertyChanged(nameof(CurrentVariantId));

            _steps = _engine.BuildSteps(new Prayer
            {
                Kind = PrayerKind.Custom,
                LanguageCode = _languageCode,
                CustomDevotionId = bundleId,
                VariantId = _variantId,
            });
            _index = 0;
            ShowsBeadTrack = _steps.Any(s => s.DecadeIndex.HasValue);
            SeasonColor = _calendar.GetSeasonColorForToday();

            RenderCurrentStep();
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
