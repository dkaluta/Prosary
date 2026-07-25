using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Views;

namespace Prosary.ViewModels;

/// <summary>UI-only choice for the setup screen's segmented control — collapses into a plain
/// <see cref="JesusPrayerTarget.Count"/>/<see cref="JesusPrayerTarget.Unbounded"/> the moment
/// Begin is tapped, so nothing downstream ever sees "custom" as a distinct runtime value. Matches
/// Android's private <c>SetupOption</c> enum in <c>JesusPrayerSetupScreen.kt</c>.</summary>
public enum JesusPrayerSetupOption
{
    ThirtyThree,
    SixtySix,
    NinetyNine,
    Custom,
    Unbounded
}

/// <summary>Drives the Jesus Prayer setup screen (repetition-count picker) — ported from
/// Android's <c>JesusPrayerSetupScreen.kt</c>, the more directly translatable reference since it
/// already uses an explicit view-state shape rather than SwiftUI's native <c>@State</c>.</summary>
public partial class JesusPrayerSetupViewModel : ObservableObject
{
    [ObservableProperty]
    private JesusPrayerSetupOption _selection = JesusPrayerSetupOption.ThirtyThree;

    [ObservableProperty]
    private string _customCountText = string.Empty;

    public bool IsCustomSelected => Selection == JesusPrayerSetupOption.Custom;

    private int? CustomCount => int.TryParse(CustomCountText, out var n) && n > 0 ? n : null;

    public bool CanBegin => Selection != JesusPrayerSetupOption.Custom || CustomCount is not null;

    private JesusPrayerTarget ResolvedTarget => Selection switch
    {
        JesusPrayerSetupOption.Unbounded => new JesusPrayerTarget.Unbounded(),
        JesusPrayerSetupOption.Custom => new JesusPrayerTarget.Count(CustomCount ?? 1),
        JesusPrayerSetupOption.ThirtyThree => new JesusPrayerTarget.Count(33),
        JesusPrayerSetupOption.SixtySix => new JesusPrayerTarget.Count(66),
        JesusPrayerSetupOption.NinetyNine => new JesusPrayerTarget.Count(99),
        _ => throw new ArgumentOutOfRangeException(nameof(Selection))
    };

    partial void OnSelectionChanged(JesusPrayerSetupOption value)
    {
        OnPropertyChanged(nameof(IsCustomSelected));
        OnPropertyChanged(nameof(CanBegin));
        BeginCommand.NotifyCanExecuteChanged();
    }

    partial void OnCustomCountTextChanged(string value)
    {
        OnPropertyChanged(nameof(CanBegin));
        BeginCommand.NotifyCanExecuteChanged();
    }

    [RelayCommand(CanExecute = nameof(CanBegin))]
    private void Begin() => Router.Navigate<JesusPrayerFlowPage>(new JesusPrayerFlowParams(PrayerId: null, Target: ResolvedTarget));

    [RelayCommand]
    private void Back() => Router.GoBack();
}
