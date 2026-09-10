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

public partial class DesktopLibraryViewModel(IPresetStore presets, PrayerRemovalService removal) : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    public Func<string, Task>? ShowError { get; set; }
    public Func<PrayerRemovalPlan, Task<bool>>? ConfirmDelete { get; set; }
    private List<Prayer> _prayers = [];
    private int _loadGeneration;

    public ObservableCollection<DesktopPrayerItem> Items { get; } = [];
    public ObservableCollection<DesktopGalleryItem> Gallery { get; } = [];

    [ObservableProperty] private string _searchText = "";
    [ObservableProperty] private string _statusMessage = "";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private DesktopPrayerItem? _selectedItem;
    [ObservableProperty] private DesktopGalleryItem? _selectedTemplate;
    [ObservableProperty] private bool _isEmpty;
    [ObservableProperty] private bool _hasNoMatches;

    public string LibraryTitle => Loc.Tr("desktop_library", "Library");
    public string GalleryTitle => Loc.Tr("desktop_gallery", "Gallery");
    public string OpenLabel => Loc.Tr("desktop_open", "Open");
    public string SettingsLabel => Loc.Tr("desktop_prayer_settings", "Prayer Settings…");
    public string DuplicateLabel => Loc.Tr("desktop_duplicate", "Duplicate");
    public string RenameLabel => Loc.Tr("desktop_rename", "Rename…");
    public string DeleteLabel => Loc.Tr("desktop_delete", "Delete Saved Prayer…");
    public string SearchLibraryLabel => Loc.Tr("desktop_search_library", "Search Prayers");
    public string SearchGalleryLabel => Loc.Tr("desktop_search_gallery", "Search the Gallery");
    public string EmptyTitle => Loc.Tr("desktop_library_empty", "Your Prayer Library");
    public string EmptyDetail => Loc.Tr("desktop_library_empty_detail", "Add a prayer from the gallery or import a prayer pack to begin.");
    public string NoMatchesTitle => Loc.Tr("desktop_no_matches", "No Matching Prayers");
    public string NoMatchesDetail => Loc.Tr("desktop_no_matches_detail", "Try another search.");
    public string AddLabel => Loc.Tr("desktop_add_to_library", "Add to Library");
    public string GalleryDetail => Loc.Tr("desktop_gallery_detail", "Choose a prayer to add a saved copy to your library.");

    partial void OnSearchTextChanged(string value) => Filter();

    public async Task LoadAsync()
    {
        var generation = ++_loadGeneration;
        try
        {
            var prayers = await presets.GetAllAsync();
            if (generation != _loadGeneration) return;
            _prayers = prayers;
            Filter();
        }
        catch (Exception error)
        {
            if (generation == _loadGeneration) await Report(Loc.Tr("desktop_library_load_failed", "Could Not Load the Library"), error);
        }
    }

    private void Filter()
    {
        var selectedId = SelectedItem?.Id;
        var query = SearchText.Trim();
        Items.Clear();
        foreach (var prayer in _prayers.OrderBy(prayer => prayer.Name, StringComparer.CurrentCultureIgnoreCase))
        {
            if (query.Length == 0 || prayer.Name.Contains(query, StringComparison.CurrentCultureIgnoreCase)
                || prayer.FavoriteSubtitle.Contains(query, StringComparison.CurrentCultureIgnoreCase))
                Items.Add(new DesktopPrayerItem(prayer));
        }
        SelectedItem = Items.FirstOrDefault(item => item.Id == selectedId);
        IsEmpty = _prayers.Count == 0;
        HasNoMatches = !IsEmpty && Items.Count == 0;
        var templateId = SelectedTemplate?.Id;
        Gallery.Clear();
        foreach (var template in DesktopPrayerLibrary.Gallery())
            if (query.Length == 0 || template.Title.Contains(query, StringComparison.CurrentCultureIgnoreCase)
                || template.Subtitle.Contains(query, StringComparison.CurrentCultureIgnoreCase)) Gallery.Add(template);
        SelectedTemplate = Gallery.FirstOrDefault(item => item.Id == templateId);
    }

    [RelayCommand]
    private async Task OpenAsync(DesktopPrayerItem? item)
    {
        item ??= SelectedItem;
        if (item is null || IsBusy) return;
        // The window manager re-fetches the saved UUID before opening or activating it.
        try { await DesktopWindowManager.OpenPrayerAsync(item.Id); }
        catch (Exception error) { await Report(Loc.Tr("desktop_library_load_failed", "Could Not Load the Library"), error); }
    }

    [RelayCommand]
    private void Edit(DesktopPrayerItem? item)
    {
        item ??= SelectedItem;
        if (item is null || IsBusy) return;
        if (item.Prayer.Kind == PrayerKind.Custom) Navigation.Navigate<RemindersOnlyEditorPage>(item.Id);
        else Navigation.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(item.Id));
    }

    [RelayCommand]
    private async Task DuplicateAsync(DesktopPrayerItem? item)
    {
        item ??= SelectedItem;
        if (item is null || IsBusy) return;
        await Mutate(async () =>
        {
            var source = await presets.GetAsync(item.Id);
            if (source is null) return;
            var all = await presets.GetAllAsync();
            var copy = DesktopPrayerLibrary.Duplicate(source, all.Select(prayer => prayer.Name));
            await presets.SaveAsync(copy);
            await LoadAsync();
            SelectedItem = Items.FirstOrDefault(candidate => candidate.Id == copy.Id);
        });
    }

    [RelayCommand]
    private async Task AddAsync(DesktopGalleryItem? template)
    {
        template ??= SelectedTemplate;
        if (template is null || IsBusy) return;
        await Mutate(async () =>
        {
            var copy = DesktopPrayerLibrary.Create(template, await presets.GetAllAsync());
            await presets.SaveAsync(copy);
            StatusMessage = Loc.Tr("desktop_added", "Added to Library") + ": " + copy.DisplayName;
            await LoadAsync();
        });
    }

    public async Task RenameAsync(DesktopPrayerItem item, string name)
    {
        if (IsBusy || string.IsNullOrWhiteSpace(name)) return;
        await Mutate(async () =>
        {
            var current = await presets.GetAsync(item.Id);
            if (current is not null) await presets.UpdateIfPresentAsync(current with { Name = name.Trim() });
            await LoadAsync();
        });
    }

    [RelayCommand]
    private async Task DeleteAsync(DesktopPrayerItem? item)
    {
        item ??= SelectedItem;
        if (item is null || IsBusy) return;
        await Mutate(async () =>
        {
            var plan = await removal.PlanAsync(item.Id);
            if (plan is null || ConfirmDelete is null || !await ConfirmDelete(plan)) return;
            await removal.DeleteAsync(item.Id);
            await LoadAsync();
        });
    }

    private async Task Mutate(Func<Task> operation)
    {
        IsBusy = true;
        try { await operation(); }
        catch (Exception error) { await Report(Loc.Tr("desktop_library_save_failed", "Could Not Save Prayer"), error); }
        finally { IsBusy = false; }
    }

    private Task Report(string title, Exception error) => ShowError?.Invoke(title + "\n\n" +
        (error is PrayerRemovalException ? PrayerRemovalService.ErrorMessage(error) : error.Message)) ?? Task.CompletedTask;
}
