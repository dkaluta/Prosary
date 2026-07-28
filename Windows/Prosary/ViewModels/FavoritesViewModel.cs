using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.Views;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the Favorites list — ported from Android's <c>FavoritesListScreen.kt</c>. Rosary and
/// Jesus Prayer are the only kinds with real per-favorite options worth naming and saving
/// multiple variants of, so they keep their own <c>ObservableCollection&lt;Prayer&gt;</c> + card
/// list + editor. Every generic (bundle-driven) devotion has nothing to configure beyond
/// reminders, so it renders as a single star row instead (see <see cref="SimpleFavoriteRow"/>),
/// in pack-load order, with no hardcoded PrayerKind case.
/// </summary>
public partial class FavoritesViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _scheduler;

    [ObservableProperty]
    private ObservableCollection<Prayer> _rosaryFavorites = [];

    [ObservableProperty]
    private ObservableCollection<Prayer> _jesusPrayerFavorites = [];

    [ObservableProperty]
    private ObservableCollection<SimpleFavoriteRow> _simpleFavorites = [];

    public FavoritesViewModel(IPresetStore presets, IReminderScheduler scheduler)
    {
        _presets = presets;
        _scheduler = scheduler;
    }

    /// <summary>Reloads the list — called on first navigation and again whenever the page is
    /// navigated back to (e.g. after the editor saves), since favorites can change out from under
    /// this page while it's off-screen.</summary>
    public async Task LoadAsync()
    {
        var all = await _presets.GetAllAsync();
        RosaryFavorites = new ObservableCollection<Prayer>(all.Where(p => p.Kind == PrayerKind.Rosary));
        JesusPrayerFavorites = new ObservableCollection<Prayer>(all.Where(p => p.Kind == PrayerKind.JesusPrayer));

        // Generic (bundle-driven) devotions — one row per discovered bundle, in pack-load
        // order, with no hardcoded PrayerKind case.
        var customRows = PrayerPackStore.CustomDevotionIds()
            .Select(bundleId => (bundleId, info: PrayerPackStore.Info(bundleId)))
            .Where(x => x.info is not null)
            .Select(x =>
            {
                var match = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == x.bundleId);
                return new SimpleFavoriteRow(
                    PrayerKind.Custom, x.info!.LocalizedDisplayName, HomeViewModel.GlyphForSystemName(x.info.IconSystemName),
                    match is not null, match?.Id, x.bundleId);
            });

        SimpleFavorites = new ObservableCollection<SimpleFavoriteRow>(customRows);
    }

    [RelayCommand]
    private void Pray(Prayer prayer)
    {
        switch (prayer.Kind)
        {
            case PrayerKind.Rosary:
                Router.Navigate<RosaryPrayerPage>(prayer.Id);
                break;
            case PrayerKind.JesusPrayer:
                Router.Navigate<JesusPrayerFlowPage>(new JesusPrayerFlowParams(prayer.Id, null));
                break;
            case PrayerKind.Custom:
                // Unreachable in practice — .Custom favorites have no "Pray" button in
                // FavoritesListPage (they render via SimpleFavoriteRowTemplate), only a star
                // toggle. Still handled defensively.
                if (prayer.CustomDevotionId is { } bundleId)
                {
                    Router.Navigate<CustomDevotionFlowPage>(new CustomDevotionFlowParams(prayer.Id, bundleId));
                }
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(prayer), prayer.Kind, "Unhandled PrayerKind in FavoritesViewModel.Pray");
        }
    }

    [RelayCommand]
    private void Edit(Prayer prayer) => Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(prayer.Id));

    // Two concrete commands rather than one CommandParameter-driven AddNew(PrayerKind) — a plain
    // XAML CommandParameter string ("Rosary") would arrive as a string, not a PrayerKind, and
    // IRelayCommand<PrayerKind> would reject it, so each "Add {kind}" button gets its own
    // no-argument command instead.
    [RelayCommand]
    private void AddNewRosary() => AddNew(PrayerKind.Rosary);

    [RelayCommand]
    private void AddNewJesusPrayer() => AddNew(PrayerKind.JesusPrayer);

    private void AddNew(PrayerKind kind) => Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(null, kind));

    [RelayCommand]
    private async Task MakeDefaultAsync(Prayer prayer)
    {
        await _presets.SaveAsync(prayer with { IsDefault = true });
        await LoadAsync();
    }

    [RelayCommand]
    private async Task DeleteAsync(Prayer prayer)
    {
        _scheduler.RemoveAll(prayer);
        await _presets.DeleteAsync(prayer);
        await LoadAsync();
    }

    /// <summary>Star toggle for the generic devotions — at most one <see cref="Prayer"/> row per
    /// devotion, matched by bundle id (not language), always saved with the sentinel language
    /// (follows the app-level default).</summary>
    [RelayCommand]
    private async Task ToggleSimpleFavoriteAsync(SimpleFavoriteRow row)
    {
        if (row.PrayerId is { } id)
        {
            var existing = await _presets.GetAsync(id);
            if (existing is not null)
            {
                _scheduler.RemoveAll(existing);
                await _presets.DeleteAsync(existing);
            }
        }
        else
        {
            await _presets.SaveAsync(new Prayer
            {
                // row.Title is the bundle's manifest display name — see LoadAsync above — so
                // it's used directly rather than row.Kind.DefaultName(), which for .Custom is
                // only a generic "Devotion" fallback.
                Name = row.Title,
                Kind = row.Kind,
                IsDefault = true,
                LanguageCode = LanguageCatalog.DefaultSentinel,
                CustomDevotionId = row.CustomDevotionId,
            });
        }

        await LoadAsync();
    }

    /// <summary>Opens <see cref="RemindersOnlyEditorPage"/> for an already-favorited generic
    /// devotion. Only reachable once favorited (see FavoritesListPage.xaml's Visibility binding)
    /// — there's no <see cref="SimpleFavoriteRow.PrayerId"/> to attach reminders to otherwise.</summary>
    [RelayCommand]
    private void EditReminders(SimpleFavoriteRow row)
    {
        if (row.PrayerId is { } id)
        {
            Router.Navigate<RemindersOnlyEditorPage>(id);
        }
    }

    /// <summary>Non-null while an import just failed — FavoritesListPage shows it in a
    /// ContentDialog and clears it.</summary>
    [ObservableProperty]
    private string? _importError;

    /// <summary>Imports a user-picked .prosaryprayer file and reloads so the new devotion's
    /// star row appears — see <see cref="PrayerPackStore.InstallPack"/> for the validation.</summary>
    public async Task ImportPackAsync(byte[] bytes)
    {
        try
        {
            PrayerPackStore.InstallPack(bytes);
            await LoadAsync();
        }
        catch (PrayerPackStore.InstallException e)
        {
            ImportError = e.Message;
        }
    }

    /// <summary>Removes a user-imported bundle (file + registration + its favorite row, whose
    /// reminders are cancelled first).</summary>
    [RelayCommand]
    private async Task RemoveInstalledAsync(SimpleFavoriteRow row)
    {
        if (row.CustomDevotionId is not { } bundleId || !row.IsInstalled) return;
        if (row.PrayerId is { } prayerId && await _presets.GetAsync(prayerId) is { } favorite)
        {
            _scheduler.RemoveAll(favorite);
            await _presets.DeleteAsync(favorite);
        }

        PrayerPackStore.RemoveInstalledPack(bundleId);
        await LoadAsync();
    }

    [RelayCommand]
    private void Back() => Router.GoBack();
}
