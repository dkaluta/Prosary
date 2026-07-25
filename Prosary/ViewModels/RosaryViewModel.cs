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
    private readonly RosaryEngine _engine;

    private IReadOnlyList<RosaryStep> _steps = [];
    private int _index;
    private string _languageCode = LanguageCatalog.DefaultCode;

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

    /// <summary>First half of <see cref="BottomBeads"/>, for the wide layout's split-column
    /// fallback when <see cref="HasRoomForSingleMinorColumn"/> is false — matches iOS's
    /// <c>MinorBeadsTwoColumnView</c> split exactly (first <c>(count+1)/2</c> beads).</summary>
    public IReadOnlyList<BeadInfo> BottomBeadsColumn1 => BottomBeads.Take((BottomBeads.Count + 1) / 2).ToList();

    public IReadOnlyList<BeadInfo> BottomBeadsColumn2 => BottomBeads.Skip((BottomBeads.Count + 1) / 2).ToList();

    public string MysteryImageFile => MysteryImageKey == "cross_placeholder"
        ? "ms-appx:///Assets/Images/cross_placeholder.png"
        : $"ms-appx:///Assets/Images/{MysteryImageKey}.jpg";

    public string NextButtonText => IsLastStep ? "Finish" : "Next";

    public bool HasSubtitle => !string.IsNullOrEmpty(Subtitle);

    public RosaryViewModel(IPresetStore presets, RosaryEngine engine, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _engine = engine;
        SeasonColor = calendar.GetSeasonColorForToday();
    }

    public async Task LoadAsync(Guid? prayerId)
    {
        try
        {
            var prayer = prayerId is { } id ? await _presets.GetAsync(id) : null;
            prayer ??= await _presets.GetDefaultAsync(PrayerKind.Rosary);
            if (prayer is null)
            {
                Header = "No Rosary favorites yet";
                Body = "Add a Rosary favorite first.";
                return;
            }

            _languageCode = prayer.ResolvedLanguageCode;
            IsRightToLeft = LanguageCatalog.Resolve(_languageCode).IsRightToLeft;
            _steps = _engine.BuildSteps(prayer);
            _index = 0;

            _totalDecades = _steps.Any(s => s.DecadeIndex.HasValue)
                ? _steps.Where(s => s.DecadeIndex.HasValue).Max(s => s.DecadeIndex!.Value) + 1
                : 0;
            _firstDecadeStepIndex = _steps.Select((s, i) => (s, i)).Where(t => t.s.DecadeIndex.HasValue)
                .Select(t => (int?)t.i).FirstOrDefault() ?? -1;
            _antiphonStepIndex = _steps.Select((s, i) => (s, i)).Where(t => t.s.IsAntiphon)
                .Select(t => (int?)t.i).FirstOrDefault() ?? -1;
            _hasClosingCross = prayer.Rosary.IncludeFinalSignOfCross;

            RenderCurrentStep();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[RosaryViewModel] Failed to load Rosary session: {ex}");
            Header = "Something went wrong";
            Body = "This Rosary session couldn't be loaded. Please go back and try again.";
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
        var layout = BeadLayout.Build(_steps, _index, _hasClosingCross);

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
}
