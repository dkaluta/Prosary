using System.ComponentModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>The day's source-appointed Gospel, or first appointment, using the ordinary offline passage reader.</summary>
public sealed partial class ScriptureOfDayControl : UserControl
{
    private HomeViewModel? _today;
    public string Title => Loc.Tr("scripture_of_day", "Scripture of the Day");
    public string EmptyLabel => Loc.Tr("home_widgets_no_readings", "No readings are available for this date.");
    public DesktopReadingsViewModel Readings { get; } = new();
    public HomeViewModel? Today
    {
        get => _today;
        set
        {
            if (_today == value) return;
            if (IsLoaded && _today is not null) _today.PropertyChanged -= OnTodayChanged;
            _today = value;
            if (IsLoaded && _today is not null) _today.PropertyChanged += OnTodayChanged;
            if (IsLoaded) Refresh();
        }
    }

    public ScriptureOfDayControl()
    {
        InitializeComponent();
        Loaded += (_, _) =>
        {
            if (_today is not null) _today.PropertyChanged += OnTodayChanged;
            AppSettings.ReadingsEditionChanged += OnEditionChanged;
            AppSettings.TypographyChanged += OnTypographyChanged;
            BibleLibraryStore.Default.Changed += OnBibleChanged;
            Refresh();
        };
        Unloaded += (_, _) =>
        {
            if (_today is not null) _today.PropertyChanged -= OnTodayChanged;
            AppSettings.ReadingsEditionChanged -= OnEditionChanged;
            AppSettings.TypographyChanged -= OnTypographyChanged;
            BibleLibraryStore.Default.Changed -= OnBibleChanged;
        };
    }

    private void OnTodayChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(HomeViewModel.SelectedTodayDate) or nameof(HomeViewModel.TodayReadings)) Refresh();
    }
    private void OnEditionChanged() => DispatcherQueue.TryEnqueue(() => { if (IsLoaded) Refresh(); });
    private void OnTypographyChanged() => DispatcherQueue.TryEnqueue(() => { if (IsLoaded) Readings.RefreshTypography(); });
    private void OnBibleChanged(string id) => DispatcherQueue.TryEnqueue(() =>
    {
        if (IsLoaded) foreach (var row in Readings.ScriptureOfDay) row.InvalidateText();
    });

    private void Refresh()
    {
        if (_today is null) return;
        Readings.Refresh(_today, showsAllDailyReadings: true);
        DateHeading.Text = _today.SelectedDateText;
        EmptyMessage.Visibility = Readings.ScriptureOfDay.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }
}
