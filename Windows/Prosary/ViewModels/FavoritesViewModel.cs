using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
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
/// list + editor. The other 5 kinds render as a single star row each instead (see
/// <see cref="SimpleFavoriteRow"/>) — this is where Windows benefits most from the simplification:
/// what would otherwise be 5 more parallel <c>ObservableCollection&lt;Prayer&gt;</c> properties
/// and 5 more <c>AddNewX()</c> commands (kept duplicated pre-refactor only because WinUI's
/// command-binding model doesn't cleanly support one parameterized command bound 5 ways from
/// XAML) collapse into one list and two shared, parameterized commands, since a star toggle takes
/// exactly one argument (the row) rather than needing to distinguish "add" from "which kind".
/// </summary>
public partial class FavoritesViewModel : ObservableObject
{
    private static readonly PrayerKind[] SimplifiedKinds =
    [
        PrayerKind.Angelus,
        PrayerKind.StationsOfTheCross,
        PrayerKind.FranciscanCrown,
        PrayerKind.SevenSorrows,
        PrayerKind.DivineMercyChaplet,
    ];

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
        SimpleFavorites = new ObservableCollection<SimpleFavoriteRow>(SimplifiedKinds.Select(kind =>
        {
            var match = all.FirstOrDefault(p => p.Kind == kind);
            return new SimpleFavoriteRow(kind, match is not null, match?.Id);
        }));
    }

    [RelayCommand]
    private void Pray(Prayer prayer)
    {
        switch (prayer.Kind)
        {
            case PrayerKind.Rosary:
                Router.Navigate<RosaryPrayerPage>(prayer.Id);
                break;
            case PrayerKind.Angelus:
                Router.Navigate<AngelusFlowPage>(prayer.Id);
                break;
            case PrayerKind.JesusPrayer:
                Router.Navigate<JesusPrayerFlowPage>(new JesusPrayerFlowParams(prayer.Id, null));
                break;
            case PrayerKind.StationsOfTheCross:
                Router.Navigate<StationsFlowPage>(prayer.Id);
                break;
            case PrayerKind.FranciscanCrown:
                Router.Navigate<FranciscanCrownFlowPage>(prayer.Id);
                break;
            case PrayerKind.SevenSorrows:
                Router.Navigate<SevenSorrowsFlowPage>(prayer.Id);
                break;
            case PrayerKind.DivineMercyChaplet:
                Router.Navigate<DivineMercyFlowPage>(prayer.Id);
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

    /// <summary>Star toggle for the 5 simplified kinds — at most one <see cref="Prayer"/> row per
    /// kind, matched by kind alone (not language), always saved with the sentinel language
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
                Name = row.Kind.DefaultName(),
                Kind = row.Kind,
                IsDefault = true,
                LanguageCode = LanguageCatalog.DefaultSentinel,
            });
        }

        await LoadAsync();
    }

    /// <summary>Opens <see cref="RemindersOnlyEditorPage"/> for an already-favorited simplified
    /// kind. Only reachable once favorited (see FavoritesListPage.xaml's Visibility binding) —
    /// there's no <see cref="SimpleFavoriteRow.PrayerId"/> to attach reminders to otherwise.</summary>
    [RelayCommand]
    private void EditReminders(SimpleFavoriteRow row)
    {
        if (row.PrayerId is { } id)
        {
            Router.Navigate<RemindersOnlyEditorPage>(id);
        }
    }

    [RelayCommand]
    private void Back() => Router.GoBack();
}
