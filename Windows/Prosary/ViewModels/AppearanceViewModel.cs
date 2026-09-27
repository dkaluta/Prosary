using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;

namespace Prosary.ViewModels;

/// <summary>The Appearance subpage uses the existing app-wide color preference.</summary>
public partial class AppearanceViewModel : ObservableObject
{
    private bool _isActive;
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    public string Title => Loc.Tr("settings_appearance", "Appearance");
    public string ColorLabel => Loc.Tr("SetAppColor/Header", "App color");
    public string BackLabel => Loc.Tr("CommandsBack", "Back");
    public IReadOnlyList<AppColorChoiceViewModel> AppColorOptions { get; } = AppColorPalette.All
        .Select((option, index) => new AppColorChoiceViewModel(option, index < AppColorPalette.All.Count - 1))
        .ToArray();

    public AppearanceViewModel()
    {
        _selectedAppColor = AppColorOptions.First(option => option.Id == AppSettings.AppColor);
        _selectedAppColor.IsSelected = true;
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

    private void RefreshSelection() => SelectedAppColor =
        AppColorOptions.First(option => option.Id == AppSettings.AppColor);

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
