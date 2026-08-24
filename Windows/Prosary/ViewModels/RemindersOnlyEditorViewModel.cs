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
/// Drives the compact editor for an existing <see cref="Prayer"/> row. Generic bundles expose
/// schema-driven <c>options.json</c> choices plus reminders; Rosary/Jesus rows use it for
/// reminder-only actions. This ViewModel never creates a row. Bundle reminder presets come from
/// the manifest. Mirrors iOS's RemindersOnlyEditorView/Android's RemindersOnlyEditorScreen.
/// </summary>
public partial class RemindersOnlyEditorViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _scheduler;

    private Prayer? _originalPrayer;

    public RemindersEditorViewModel RemindersEditor { get; } = new();

    public ObservableCollection<DevotionOptionRowViewModel> OptionRows { get; } = new();

    [ObservableProperty]
    private string _title = string.Empty;

    [ObservableProperty]
    private bool _hasOptions;

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
        // carry per-bundle text) — read the real name and reminder presets from the bundle's own
        // manifest.
        var info = prayer.Kind == PrayerKind.Custom && prayer.CustomDevotionId is { } bundleId
            ? PrayerPackStore.Info(bundleId)
            : null;
        Title = info?.LocalizedDisplayName ?? prayer.Kind.DisplayName();

        OptionRows.Clear();
        if (prayer.CustomDevotionId is { } devotionId)
        {
            foreach (var option in PrayerPackStore.Options(devotionId))
            {
                // Rows read through to the option's declared default so they show the effective
                // value even before the user has ever touched them; Save stores explicit
                // overrides for every row.
                var value = prayer.CustomOptions.GetValueOrDefault(option.Key) ?? option.DefaultValue;
                OptionRows.Add(new DevotionOptionRowViewModel(option, value));
            }
        }

        HasOptions = OptionRows.Count > 0;
        RemindersEditor.PresetHours = info?.ReminderPresetHours ?? [];
        RemindersEditor.PresetFooter = info?.LocalizedReminderPresetFooter;
        RemindersEditor.Reminders = new ObservableCollection<PrayerReminder>(prayer.Reminders);
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (_originalPrayer is not { } original)
        {
            return;
        }

        var customOptions = new Dictionary<string, string>(original.CustomOptions);
        foreach (var row in OptionRows)
        {
            customOptions[row.Key] = row.Value;
        }

        var toSave = original with
        {
            Reminders = [.. RemindersEditor.Reminders],
            CustomOptions = customOptions,
        };
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

/// <summary>One schema-driven row of the editor's Options section — a ToggleSwitch (toggle
/// kind) or a ComboBox of the declared cases (choice kind), initialized from the favorite's
/// stored value (or the option's default) and read back via <see cref="Value"/> on save.</summary>
public partial class DevotionOptionRowViewModel : ObservableObject
{
    private readonly CustomDevotionOption _option;

    [ObservableProperty]
    private bool _isOn;

    [ObservableProperty]
    private CustomDevotionOption.Case? _selectedCase;

    public DevotionOptionRowViewModel(CustomDevotionOption option, string value)
    {
        _option = option;
        _isOn = value == "true";
        _selectedCase = option.Cases?.FirstOrDefault(c => c.Id == value) ?? option.Cases?.FirstOrDefault();
    }

    public string Key => _option.Key;
    public string Label => _option.LocalizedName;
    public bool IsToggle => _option.Kind == CustomDevotionOption.OptionKind.Toggle;
    public bool IsChoice => _option.Kind == CustomDevotionOption.OptionKind.Choice;
    public IReadOnlyList<CustomDevotionOption.Case> Cases => _option.Cases ?? [];

    /// <summary>The row's current value in the CustomOptions string encoding — "true"/"false"
    /// for a toggle, the selected case id for a choice.</summary>
    public string Value => IsToggle
        ? (IsOn ? "true" : "false")
        : SelectedCase?.Id ?? _option.DefaultValue;
}
