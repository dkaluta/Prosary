using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Views;

namespace Prosary.ViewModels;

/// <summary>
/// Home → Rosary lands here instead of launching a session directly: the default preset up top
/// (one tap to pray), then "Pray any Rosary" (an ad-hoc session), then the remaining presets.
/// The ad-hoc section exposes the mystery selection inline and inherits every other option from
/// the default preset — full customization lives in the preset editor (a deliberate, documented
/// divergence from iOS/Android, whose pickers embed the whole options editor). Preset management
/// stays in Favorites. Mirrors iOS's RosaryPresetPickerView/Android's RosaryPresetPickerScreen.
/// </summary>
public partial class RosaryPresetPickerViewModel : ObservableObject
{
    private readonly IPresetStore _presets;

    [ObservableProperty]
    private Prayer? _defaultPreset;

    [ObservableProperty]
    private ObservableCollection<Prayer> _otherPresets = [];

    [ObservableProperty]
    private bool _hasDefaultPreset;

    [ObservableProperty]
    private bool _hasOtherPresets;

    // Ad-hoc mystery selection (seeded from the default preset; the rest of RosaryOptions is
    // inherited from it unchanged).
    public IReadOnlyList<MysterySelectionMode> SelectionModes { get; } = Enum.GetValues<MysterySelectionMode>();
    public IReadOnlyList<MysteryGroup> Groups { get; } = Enum.GetValues<MysteryGroup>();
    public IReadOnlyList<int> Ordinals { get; } = [1, 2, 3, 4, 5];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowsGroupPicker))]
    [NotifyPropertyChangedFor(nameof(ShowsOrdinalPicker))]
    private MysterySelectionMode _selectedMode = MysterySelectionMode.TodaysMysteries;

    [ObservableProperty]
    private MysteryGroup _selectedGroup = MysteryGroup.Joyful;

    [ObservableProperty]
    private int _selectedOrdinal = 1;

    public bool ShowsGroupPicker =>
        SelectedMode is MysterySelectionMode.Specific or MysterySelectionMode.SingleMystery;

    public bool ShowsOrdinalPicker => SelectedMode is MysterySelectionMode.SingleMystery;

    public RosaryPresetPickerViewModel(IPresetStore presets)
    {
        _presets = presets;
    }

    public async Task LoadAsync()
    {
        var rosaries = (await _presets.GetAllAsync()).Where(p => p.Kind == PrayerKind.Rosary).ToList();
        DefaultPreset = rosaries.FirstOrDefault(p => p.IsDefault);
        OtherPresets = new ObservableCollection<Prayer>(rosaries.Where(p => !p.IsDefault));
        HasDefaultPreset = DefaultPreset is not null;
        HasOtherPresets = OtherPresets.Count > 0;

        if (DefaultPreset is { } preset)
        {
            SelectedMode = preset.Rosary.MysterySelectionMode;
            SelectedGroup = preset.Rosary.SpecificMysteryGroup;
            SelectedOrdinal = preset.Rosary.SpecificMysteryOrder;
        }
    }

    /// <summary>The ad-hoc Prayer the current quick-setup selection describes — the default
    /// preset's options with the mystery selection swapped in.</summary>
    public Prayer AdHocPrayer()
    {
        var seed = DefaultPreset?.Rosary ?? new RosaryOptions();
        return new Prayer
        {
            Kind = PrayerKind.Rosary,
            LanguageCode = DefaultPreset?.LanguageCode ?? LanguageCatalog.DefaultSentinel,
            Rosary = seed with
            {
                MysterySelectionMode = SelectedMode,
                SpecificMysteryGroup = SelectedGroup,
                SpecificMysteryOrder = SelectedOrdinal,
            },
        };
    }

    [RelayCommand]
    private void PrayPreset(Prayer preset) => Router.Navigate<RosaryPrayerPage>(preset.Id);

    [RelayCommand]
    private void PrayAdHoc() => Router.Navigate<RosaryPrayerPage>(AdHocPrayer());

    /// <summary>Keeps the quick-setup selection as a new preset — never stealing the default
    /// slot unless it's the first preset.</summary>
    public async Task SaveAsPresetAsync(string name)
    {
        var prayer = AdHocPrayer() with
        {
            Name = string.IsNullOrWhiteSpace(name) ? PrayerKind.Rosary.DefaultName() : name.Trim(),
            IsDefault = DefaultPreset is null && OtherPresets.Count == 0,
        };
        await _presets.SaveAsync(prayer);
        await LoadAsync();
    }

    [RelayCommand]
    private void EditPreset(Prayer preset) =>
        Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(preset.Id));

    [RelayCommand]
    private void EditReminders(Prayer preset) =>
        Router.Navigate<RemindersOnlyEditorPage>(preset.Id);

    [RelayCommand]
    private async Task MakeDefaultAsync(Prayer preset)
    {
        foreach (var other in await _presets.GetAllAsync())
        {
            if (other.Kind != PrayerKind.Rosary)
            {
                continue;
            }

            var shouldBeDefault = other.Id == preset.Id;
            if (other.IsDefault != shouldBeDefault)
            {
                await _presets.SaveAsync(other with { IsDefault = shouldBeDefault });
            }
        }

        await LoadAsync();
    }

    [RelayCommand]
    private async Task DeletePresetAsync(Prayer preset)
    {
        await _presets.DeleteAsync(preset);
        await LoadAsync();
    }

    [RelayCommand]
    private void Back() => Router.GoBack();
}
