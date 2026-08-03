using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Windows.Storage;

namespace Prosary.ViewModels;

/// <summary>One auto-advance choice for the Settings combo box.</summary>
public sealed record AutoAdvanceOption(int Seconds, string Label);

/// <summary>One app-UI-language choice; an empty <see cref="Tag"/> means "follow Windows".</summary>
public sealed record AppLanguageOption(string Tag, string Label);

/// <summary>
/// App-wide preferences (v0.7: populated beyond the single language picker — auto-advance,
/// Home order reset, and downloads management, mirroring iOS's <c>SettingsView</c> and
/// Android's <c>SettingsScreen.kt</c> per port parity). The remove-all confirmation dialog
/// lives in the page's code-behind (dialogs need a XamlRoot); it calls
/// <see cref="RemoveAllInstalledPacks"/> here.
/// </summary>
public partial class SettingsViewModel : ObservableObject
{
    [ObservableProperty]
    private LanguageOption _selectedLanguage = LanguageCatalog.Resolve(AppSettings.DefaultLanguageCode);

    public IReadOnlyList<LanguageOption> LanguageOptions => LanguageCatalog.All;

    partial void OnSelectedLanguageChanged(LanguageOption value) => AppSettings.SetDefaultLanguageCode(value.Code);

    // The same app-wide setting the flow toolbars offer — surfaced here so it's discoverable
    // outside a session. Static so the selection's field initializer can consult it.
    private static readonly IReadOnlyList<AutoAdvanceOption> AllAutoAdvanceOptions =
    [
        new(0, Loc.Tr("auto_advance_off", "Off")),
        new(3, string.Format(Loc.Tr("auto_advance_every", "Every {0} seconds"), 3)),
        new(5, string.Format(Loc.Tr("auto_advance_every", "Every {0} seconds"), 5)),
        new(10, string.Format(Loc.Tr("auto_advance_every", "Every {0} seconds"), 10)),
    ];

    public IReadOnlyList<AutoAdvanceOption> AutoAdvanceOptions => AllAutoAdvanceOptions;

    // The app's UI language (v0.7, Gamaliel item 3 — Hebrew UI). Windows resolves resources from
    // the user's Windows language list; this override lets someone keep Windows in English but
    // pray-app in Hebrew (or vice versa). Applies fully after a relaunch — the footer says so.
    private static readonly IReadOnlyList<AppLanguageOption> AllAppLanguages =
    [
        new(string.Empty, Loc.Tr("settings_app_language_system", "System default")),
        new("en-US", "English"),
        new("he", "עברית"),
    ];

    public IReadOnlyList<AppLanguageOption> AppLanguageOptions => AllAppLanguages;

    [ObservableProperty]
    private AppLanguageOption _selectedAppLanguage =
        AllAppLanguages.FirstOrDefault(o => o.Tag == CurrentLanguageOverride()) ?? AllAppLanguages[0];

    partial void OnSelectedAppLanguageChanged(AppLanguageOption value)
    {
        try
        {
            Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride = value.Tag;
        }
        catch
        {
            // Unpackaged (unit-test) context — nothing to persist to.
        }
    }

    private static string CurrentLanguageOverride()
    {
        try
        {
            return Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride;
        }
        catch
        {
            return string.Empty;
        }
    }

    [ObservableProperty]
    private AutoAdvanceOption _selectedAutoAdvance =
        AllAutoAdvanceOptions.FirstOrDefault(o => o.Seconds == AppSettings.AutoAdvanceSeconds) ?? AllAutoAdvanceOptions[0];

    partial void OnSelectedAutoAdvanceChanged(AutoAdvanceOption value) => AppSettings.SetAutoAdvanceSeconds(value.Seconds);

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(ResetHomeOrderCommand))]
    private bool _homeOrderIsCustom = HomeOrder.Saved().Count > 0;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(InstalledCountLabel))]
    [NotifyCanExecuteChangedFor(nameof(RequestRemoveAllDownloadsCommand))]
    private int _installedCount = PrayerPackStore.InstalledBundleIds().Count;

    public string InstalledCountLabel => string.Format(Loc.Tr("settings_installed_devotions", "Installed devotions: {0}"), InstalledCount);

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(AudioCacheLabel))]
    [NotifyCanExecuteChangedFor(nameof(ClearAudioCacheCommand))]
    private long _audioCacheBytes = AudioCacheSize();

    public string AudioCacheLabel => AudioCacheBytes > 0
        ? string.Format(Loc.Tr("settings_clear_audio_cache_size", "Clear Audio Cache ({0})"), FormatBytes(AudioCacheBytes))
        : Loc.Tr("settings_clear_audio_cache", "Clear Audio Cache");

    /// <summary>The page's code-behind sets this to present the confirmation dialog when the
    /// remove-all button is clicked (dialogs need a XamlRoot the ViewModel doesn't have).</summary>
    public Func<Task<bool>>? ConfirmRemoveAll { get; set; }

    [RelayCommand(CanExecute = nameof(HomeOrderIsCustom))]
    private void ResetHomeOrder()
    {
        HomeOrder.Reset();
        HomeOrderIsCustom = false;
    }

    private bool CanClearAudioCache => AudioCacheBytes > 0;

    [RelayCommand(CanExecute = nameof(CanClearAudioCache))]
    private void ClearAudioCache()
    {
        var root = AudioCacheRoot();
        if (Directory.Exists(root))
        {
            try
            {
                Directory.Delete(root, recursive: true);
            }
            catch (IOException)
            {
                // A track is playing from the cache; whatever could be deleted is gone.
            }
        }
        AudioCacheBytes = AudioCacheSize();
    }

    private bool CanRemoveAllDownloads => InstalledCount > 0;

    [RelayCommand(CanExecute = nameof(CanRemoveAllDownloads))]
    private async Task RequestRemoveAllDownloads()
    {
        if (ConfirmRemoveAll is null || !await ConfirmRemoveAll())
        {
            return;
        }
        RemoveAllInstalledPacks();
    }

    public void RemoveAllInstalledPacks()
    {
        foreach (var bundleId in PrayerPackStore.InstalledBundleIds().ToList())
        {
            PrayerPackStore.RemoveInstalledPack(bundleId);
        }
        InstalledCount = PrayerPackStore.InstalledBundleIds().Count;
    }

    [RelayCommand]
    private async Task OpenLink(string url) => await Windows.System.Launcher.LaunchUriAsync(new Uri(url));

    [RelayCommand]
    private void Back() => Router.GoBack();

    private static string AudioCacheRoot() => Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "PrayerAudio");

    private static long AudioCacheSize()
    {
        var root = AudioCacheRoot();
        if (!Directory.Exists(root))
        {
            return 0;
        }
        return Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories).Sum(f => new FileInfo(f).Length);
    }

    private static string FormatBytes(long bytes) => bytes switch
    {
        >= 1024 * 1024 => $"{bytes / (1024.0 * 1024.0):F1} MB",
        >= 1024 => $"{bytes / 1024.0:F0} KB",
        _ => $"{bytes} B",
    };
}
