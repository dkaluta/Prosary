using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;

namespace Prosary.ViewModels;

/// <summary>
/// App-wide preferences — currently just the default prayer language, used whenever a favorite's
/// own language is left at "Default" (see <see cref="LanguageCatalog.DefaultSentinel"/>). Ported
/// from Android's <c>SettingsScreen.kt</c> — Windows' equivalent of Android having no external
/// settings surface to extend, the same reason that screen exists there instead of relying
/// entirely on an OS-level settings page the way iOS's Settings.bundle entry does.
/// </summary>
public partial class SettingsViewModel : ObservableObject
{
    [ObservableProperty]
    private LanguageOption _selectedLanguage = LanguageCatalog.Resolve(AppSettings.DefaultLanguageCode);

    public IReadOnlyList<LanguageOption> LanguageOptions => LanguageCatalog.All;

    partial void OnSelectedLanguageChanged(LanguageOption value) => AppSettings.SetDefaultLanguageCode(value.Code);

    [RelayCommand]
    private void Back() => Router.GoBack();
}
