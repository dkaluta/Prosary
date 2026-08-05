using System.Collections.ObjectModel;
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
/// <summary>One downloaded or hand-imported devotion, listed under Settings → Downloads with the
/// two actions the retired Favorites screen used to carry: a copy out for editing at
/// compose.prosary.app (Gamaliel item 7) and a removal. Top-level rather than nested because
/// x:DataType has no syntax for a nested type.</summary>
public sealed record InstalledDevotionRow(string BundleId, string Title);

public partial class SettingsViewModel : ObservableObject
{
    // The stored code may name a rite ("he-x-gamliel"), so this row holds its base language and
    // the rite row below chooses among that language's uses.
    [ObservableProperty]
    private LanguageOption _selectedLanguage = LanguageCatalog.All.FirstOrDefault(
        l => l.Code == (LanguageCatalog.BaseLanguage(AppSettings.DefaultLanguageCode)
                        ?? AppSettings.DefaultLanguageCode))
        ?? LanguageCatalog.Resolve(AppSettings.DefaultLanguageCode);

    public IReadOnlyList<LanguageOption> LanguageOptions => LanguageCatalog.All;

    partial void OnSelectedLanguageChanged(LanguageOption value)
    {
        // Choosing a language keeps its rite when it has one, and drops it otherwise.
        var rites = LanguageCatalog.Rites(value.Code);
        AppSettings.SetDefaultLanguageCode(rites.Count > 0 ? rites[0].Code : value.Code);
        RiteOptions = rites;
        SelectedRite = rites.FirstOrDefault();
        OnPropertyChanged(nameof(ShowsRitePicker));
    }

    /// <summary>The rites of the chosen language — empty (and hidden) when there is only one way
    /// to pray it. A rite that lacks a prayer reads it in the language's own wording, so this is
    /// a preference, never a restriction.</summary>
    [ObservableProperty]
    private IReadOnlyList<LanguageOption> _riteOptions =
        LanguageCatalog.Rites(AppSettings.DefaultLanguageCode);

    [ObservableProperty]
    private LanguageOption? _selectedRite =
        LanguageCatalog.Rites(AppSettings.DefaultLanguageCode)
            .FirstOrDefault(r => r.Code == AppSettings.DefaultLanguageCode)
        ?? LanguageCatalog.Rites(AppSettings.DefaultLanguageCode).FirstOrDefault();

    public bool ShowsRitePicker => RiteOptions.Count > 1;

    partial void OnSelectedRiteChanged(LanguageOption? value)
    {
        if (value is not null)
        {
            AppSettings.SetDefaultLanguageCode(value.Code);
        }
    }

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

    public ObservableCollection<InstalledDevotionRow> InstalledDevotions { get; } = [];

    public bool HasInstalledDevotions => InstalledDevotions.Count > 0;

    /// <summary>Re-reads the installed list; called when Settings appears and after any change.</summary>
    public void RefreshInstalledDevotions()
    {
        InstalledDevotions.Clear();
        foreach (var bundleId in PrayerPackStore.InstalledBundleIds())
        {
            InstalledDevotions.Add(new InstalledDevotionRow(
                bundleId, PrayerPackStore.Info(bundleId)?.LocalizedDisplayName ?? bundleId));
        }

        InstalledCount = PrayerPackStore.InstalledBundleIds().Count;
        OnPropertyChanged(nameof(HasInstalledDevotions));
    }

    /// <summary>Installs a bundle the user picked; returns the error to show, or null.</summary>
    public string? ImportPack(byte[] bytes)
    {
        try
        {
            PrayerPackStore.InstallPack(bytes);
        }
        catch (PrayerPackStore.InstallException error)
        {
            return error.Message;
        }

        RefreshInstalledDevotions();
        return null;
    }

    /// <summary>The file a devotion was installed from — what Export copies out.</summary>
    public static string? InstalledPackPath(string bundleId) => PrayerPackStore.InstalledPackPath(bundleId);

    [RelayCommand]
    private void RemoveInstalled(InstalledDevotionRow row)
    {
        PrayerPackStore.RemoveInstalledPack(row.BundleId);
        RefreshInstalledDevotions();
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
