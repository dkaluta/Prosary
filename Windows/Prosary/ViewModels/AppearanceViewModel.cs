using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;

namespace Prosary.ViewModels;

/// <summary>The Appearance subpage uses the existing app-wide color preference.</summary>
public partial class AppearanceViewModel : ObservableObject
{
    public record AppearanceChoice(string Id, string Label);
    public string ModeLabel => Loc.Tr("appearance_mode", "Display Mode");
    public string PaletteLabel => Loc.Tr("appearance_palette", "Color Palette");
    public IReadOnlyList<AppearanceChoice> ThemeOptions { get; } = new[] { "system", "light", "dark" }.Select(id => new AppearanceChoice(id, Loc.Tr("appearance_" + id, id))).ToArray();
    public IReadOnlyList<AppearanceChoice> PaletteOptions { get; } = new[] { "native", "stainedGlass", "garden" }.Select(id => new AppearanceChoice(id, Loc.Tr("appearance_" + id, id))).ToArray();
    [ObservableProperty] private AppearanceChoice? _selectedTheme;
    [ObservableProperty] private AppearanceChoice? _selectedPalette;
    partial void OnSelectedThemeChanged(AppearanceChoice? value) { if (value is not null && value.Id != AppSettings.AppThemeMode) AppSettings.SetAppThemeMode(value.Id); }
    partial void OnSelectedPaletteChanged(AppearanceChoice? value) { if (value is not null && value.Id != AppSettings.AppPalette) AppSettings.SetAppPalette(value.Id); }
    private bool _isActive;
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    public string Title => Loc.Tr("settings_appearance", "Appearance");
    public string ColorLabel => Loc.Tr("SetAppColor/Header", "App color");
    public string BackLabel => Loc.Tr("CommandsBack", "Back");
    public string CustomAccentLabel => Loc.Tr("appearance_custom_accent", "Custom Accent Color");
    public string ResetAccentLabel => Loc.Tr("appearance_reset_accent", "Use App Color");
    private bool _refreshingAccent;

    [ObservableProperty] private Windows.UI.Color _customAccent;

    partial void OnCustomAccentChanged(Windows.UI.Color value)
    {
        if (!_refreshingAccent)
            AppSettings.SetCustomAccentColorHex($"#{value.R:X2}{value.G:X2}{value.B:X2}");
    }

    [RelayCommand] private void ResetAccent() => AppSettings.SetCustomAccentColorHex("");
    public IReadOnlyList<AppColorChoiceViewModel> AppColorOptions { get; } = AppColorPalette.All
        .Select((option, index) => new AppColorChoiceViewModel(option, index < AppColorPalette.All.Count - 1))
        .ToArray();

    public AppearanceViewModel()
    {
        _selectedTheme = ThemeOptions.First(option => option.Id == AppSettings.AppThemeMode);
        _selectedPalette = PaletteOptions.First(option => option.Id == AppSettings.AppPalette);
        _selectedAppColor = AppColorOptions.First(option => option.Id == AppSettings.AppColor);
        _selectedAppColor.IsSelected = true;
        RefreshAccent();
    }

    public void Activate()
    {
        if (_isActive) return;
        _isActive = true;
        AppSettings.AppColorChanged += RefreshSelection;
        RefreshSelection();
    }

    public void Deactivate()
    {
        if (!_isActive) return;
        _isActive = false;
        AppSettings.AppColorChanged -= RefreshSelection;
    }

    private void RefreshSelection()
    {
        SelectedTheme = ThemeOptions.First(option => option.Id == AppSettings.AppThemeMode);
        SelectedPalette = PaletteOptions.First(option => option.Id == AppSettings.AppPalette);
        SelectedAppColor = AppColorOptions.First(option => option.Id == AppSettings.AppColor);
        RefreshAccent();
    }

    private void RefreshAccent()
    {
        _refreshingAccent = true;
        try
        {
            CustomAccent = AppSettings.CustomAccentColorHex.Length > 0
                ? AppColorPalette.Parse(AppSettings.CustomAccentColorHex[1..])
                : AppColorPalette.Resolve(AppSettings.AppColor).Accent(false);
        }
        finally { _refreshingAccent = false; }
    }

    [ObservableProperty]
    private AppColorChoiceViewModel _selectedAppColor;

    partial void OnSelectedAppColorChanged(AppColorChoiceViewModel value)
    {
        // A native selector can clear its selection while unloading.
        if (value is null) return;
        foreach (var option in AppColorOptions) option.IsSelected = option.Id == value.Id;
        AppSettings.SetAppColor(value.Id);
    }

    [RelayCommand]
    private void Back() => Navigation.GoBack();
}

public partial class AppColorChoiceViewModel(AppColorOption option, bool hasSeparator) : ObservableObject
{
    public string Id => option.Id;
    public string Label => option.Label;
    public string IconSource => $"ms-appx:///Assets/Icons/{option.IconFileName}";
    public bool HasSeparator => hasSeparator;

    [ObservableProperty]
    private bool _isSelected;
}
