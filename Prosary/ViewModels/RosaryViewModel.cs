using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
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
    // beads — for the narrow layout's wrapped horizontal grid.
    [ObservableProperty]
    private ObservableCollection<List<BeadInfo>> _topBeadRows = [];

    // Decade beads grouped into rows of 4 for the wide layout's vertical bead track, with the
    // opening cross left-aligned on its own row and the antiphon/closing-cross beads
    // right-aligned on their own rows — see RebuildBeads.
    [ObservableProperty]
    private ObservableCollection<BeadRow> _verticalBeadRows = [];

    [ObservableProperty]
    private ObservableCollection<BeadInfo> _bottomBeads = [];

    [ObservableProperty]
    private bool _showBottomBeads;

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

        RebuildBeads(step);
    }

    private void RebuildBeads(RosaryStep step)
    {
        var crossBead = new BeadInfo { Kind = BeadKind.Cross, State = _index == 0 ? BeadState.Current : BeadState.Completed };

        var decadeBeads = new List<BeadInfo>();
        for (var d = 0; d < _totalDecades; d++)
        {
            var state = step.DecadeIndex switch
            {
                null when _firstDecadeStepIndex < 0 || _index < _firstDecadeStepIndex => BeadState.Upcoming,
                null => BeadState.Completed, // past all decades (antiphon/closing phase)
                var current when d < current => BeadState.Completed,
                var current when d == current => BeadState.Current,
                _ => BeadState.Upcoming
            };
            decadeBeads.Add(new BeadInfo { Kind = BeadKind.Decade, State = state });
        }

        BeadInfo? antiphonBead = null;
        if (_antiphonStepIndex >= 0)
        {
            var state = _index < _antiphonStepIndex ? BeadState.Upcoming
                : _index == _antiphonStepIndex ? BeadState.Current
                : BeadState.Completed;
            antiphonBead = new BeadInfo { Kind = BeadKind.Antiphon, State = state };
        }

        BeadInfo? closingCrossBead = null;
        if (_hasClosingCross)
        {
            var closingCrossIndex = _steps.Count - 1;
            closingCrossBead = new BeadInfo
            {
                Kind = BeadKind.Cross,
                State = _index < closingCrossIndex ? BeadState.Upcoming : BeadState.Current
            };
        }

        // Grouped into rows of 5 decade beads, mirroring the physical layout of a rosary's
        // Our-Father beads — the opening cross rides along with the first row, and the antiphon/
        // closing-cross beads (if any) tag onto whatever's left of the last row.
        var rows = new List<List<BeadInfo>> { new() { crossBead } };
        foreach (var decadeBead in decadeBeads)
        {
            rows[^1].Add(decadeBead);
            if (rows[^1].Count(b => b.Kind == BeadKind.Decade) % 5 == 0 && decadeBead != decadeBeads[^1])
            {
                rows.Add([]);
            }
        }

        var lastRow = rows[^1];
        if (antiphonBead is { } antiphon)
        {
            lastRow.Add(antiphon);
        }

        if (closingCrossBead is { } closing)
        {
            lastRow.Add(closing);
        }

        TopBeadRows = new ObservableCollection<List<BeadInfo>>(rows);

        // Same beads, grouped into rows of 4 for the wide layout's narrower vertical track —
        // opening cross alone at the left, decade beads centered, antiphon/closing cross each
        // alone at the right, matching where they'd hang on a physical rosary.
        var verticalRows = new List<BeadRow> { new() { Beads = [crossBead], Alignment = HorizontalAlignment.Left } };
        var currentVerticalRow = new List<BeadInfo>();
        foreach (var decadeBead in decadeBeads)
        {
            currentVerticalRow.Add(decadeBead);
            if (currentVerticalRow.Count == 4)
            {
                verticalRows.Add(new BeadRow { Beads = currentVerticalRow, Alignment = HorizontalAlignment.Center });
                currentVerticalRow = [];
            }
        }

        if (currentVerticalRow.Count > 0)
        {
            verticalRows.Add(new BeadRow { Beads = currentVerticalRow, Alignment = HorizontalAlignment.Center });
        }

        if (antiphonBead is { } antiphonV)
        {
            verticalRows.Add(new BeadRow { Beads = [antiphonV], Alignment = HorizontalAlignment.Right });
        }

        if (closingCrossBead is { } closingV)
        {
            verticalRows.Add(new BeadRow { Beads = [closingV], Alignment = HorizontalAlignment.Right });
        }

        VerticalBeadRows = new ObservableCollection<BeadRow>(verticalRows);

        if (!step.DecadeIndex.HasValue)
        {
            ShowBottomBeads = false;
            return;
        }

        var decadeStepIndices = _steps
            .Select((s, i) => (s, i))
            .Where(t => t.s.DecadeIndex == step.DecadeIndex && t.s.HailMaryIndexInDecade.HasValue)
            .Select(t => t.i)
            .ToList();
        var firstHailMaryIndex = decadeStepIndices.Min();
        var lastHailMaryIndex = decadeStepIndices.Max();

        var bottom = new List<BeadInfo>();
        for (var h = 1; h <= 10; h++)
        {
            BeadState state;
            if (_index < firstHailMaryIndex)
            {
                state = BeadState.Upcoming;
            }
            else if (_index > lastHailMaryIndex)
            {
                state = BeadState.Completed;
            }
            else
            {
                var current = step.HailMaryIndexInDecade!.Value;
                state = h < current ? BeadState.Completed : h == current ? BeadState.Current : BeadState.Upcoming;
            }

            bottom.Add(new BeadInfo { Kind = BeadKind.Decade, State = state, IsGroupStart = h > 1 && (h - 1) % 5 == 0 });
        }

        BottomBeads = new ObservableCollection<BeadInfo>(bottom);
        ShowBottomBeads = true;
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
