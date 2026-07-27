using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the lightweight reminders-only editor for the 5 non-configurable devotion kinds
/// (Angelus, Stations of the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) —
/// these have no name/language/per-favorite options to edit (see <see cref="FavoritesViewModel"/>),
/// just reminders. Reachable from the star row's bell button, and only once the kind is
/// favorited (a <see cref="Prayer"/> row must already exist to attach reminders to — this
/// ViewModel never creates one, unlike <see cref="FavoriteEditorViewModel"/>). Mirrors iOS's
/// RemindersOnlyEditorView/Android's RemindersOnlyEditorScreen.
/// </summary>
public partial class RemindersOnlyEditorViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _scheduler;

    private Prayer? _originalPrayer;

    public RemindersEditorViewModel RemindersEditor { get; } = new();

    [ObservableProperty]
    private string _title = string.Empty;

    public RemindersOnlyEditorViewModel(IPresetStore presets, IReminderScheduler scheduler)
    {
        _presets = presets;
        _scheduler = scheduler;
    }

    public async Task LoadAsync(Guid prayerId)
    {
        var prayer = await _presets.GetAsync(prayerId);
        if (prayer is null)
        {
            // The favorite was deleted out from under this screen (e.g. from another window) —
            // nothing to edit, so just back out rather than showing a blank editor.
            Router.GoBack();
            return;
        }

        _originalPrayer = prayer;
        // For .Custom, DisplayName() is only a generic fallback (a single PrayerKind case can't
        // carry per-bundle text) — read the real name from the bundle's own manifest.
        Title = prayer.Kind == PrayerKind.Custom && prayer.CustomDevotionId is { } bundleId
            ? PrayerPackStore.Info(bundleId)?.DisplayName ?? prayer.Kind.DisplayName()
            : prayer.Kind.DisplayName();
        RemindersEditor.Kind = prayer.Kind;
        RemindersEditor.Reminders = new ObservableCollection<PrayerReminder>(prayer.Reminders);
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (_originalPrayer is not { } original)
        {
            return;
        }

        var toSave = original with { Reminders = [.. RemindersEditor.Reminders] };
        await _presets.SaveAsync(toSave);

        // Cancel the original's reminders (by their old ids) before scheduling the new set —
        // Schedule() only knows how to (re)build toasts for reminder ids present in toSave, so a
        // reminder the user just deleted would otherwise never have its pending toasts removed.
        _scheduler.RemoveAll(original);
        _scheduler.Schedule(toSave);

        Router.GoBack();
    }

    [RelayCommand]
    private void Cancel() => Router.GoBack();
}
