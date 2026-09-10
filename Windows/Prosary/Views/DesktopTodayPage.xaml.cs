using System.ComponentModel;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>The desktop's independent calendar reference surface. Prayer sessions keep their
/// own dates and navigation; this page reuses the canonical Today provider and preferences.</summary>
public sealed partial class DesktopTodayPage : Page
{
    private readonly DispatcherQueueTimer _dateTimer;
    private DateOnly _lastLocalDate = DateOnly.FromDateTime(DateTime.Today);
    private bool _updatingTodayCalendar;

    public HomeViewModel ViewModel { get; }
    public SettingsViewModel Options { get; }
    public DesktopReadingsViewModel Readings { get; } = new();
    public string Title => Loc.Tr("desktop_today", "Today");
    public string OptionsLabel => Loc.Tr("SetTitle/Text", "Settings");

    public DesktopTodayPage()
    {
        ViewModel = App.Services.GetRequiredService<HomeViewModel>();
        Options = App.Services.GetRequiredService<SettingsViewModel>();
        InitializeComponent();
        NavigationCacheMode = NavigationCacheMode.Enabled;
        _dateTimer = DispatcherQueue.CreateTimer();
        _dateTimer.Interval = TimeSpan.FromMinutes(1);
        _dateTimer.Tick += (_, _) => RefreshForClock();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        ViewModel.PropertyChanged += OnTodayChanged;
        AppSettings.ReadingsEditionChanged += OnReadingEditionChanged;
        AppSettings.TypographyChanged += OnReadingTypographyChanged;
        SynchronizeOptions();
        RefreshForClock();
        Readings.Refresh(ViewModel);
        _dateTimer.Start();
    }

    private void OnOptionsFlyoutOpened(object sender, object e)
    {
        SynchronizeOptions();
        RefreshForClock();
    }

    private void SynchronizeOptions()
    {
        // A cached page may return after Settings changed in another window.
        TodayInfoStore.SelectedCalendarId = AppSettings.FeastCalendarId;
        Options.PropertyChanged -= OnOptionsChanged;
        Options.ShowTodayFeast = AppSettings.ShowTodayFeast;
        Options.ShowTodayIntention = AppSettings.ShowTodayIntention;
        Options.ShowTodayTorahPortion = AppSettings.ShowTodayTorahPortion;
        Options.SelectedFeastCalendar = Options.FeastCalendarOptions.FirstOrDefault(c => c.Id == TodayInfoStore.ResolvedCalendarId);
        Options.SelectedEasternPascha = Options.CurrentEasternPascha;
        Options.PropertyChanged += OnOptionsChanged;
    }

    private void OnUnloaded(object sender, RoutedEventArgs e)
    {
        _dateTimer.Stop();
        ViewModel.PropertyChanged -= OnTodayChanged;
        AppSettings.ReadingsEditionChanged -= OnReadingEditionChanged;
        AppSettings.TypographyChanged -= OnReadingTypographyChanged;
        Options.PropertyChanged -= OnOptionsChanged;
    }

    private void OnTodayChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName is nameof(HomeViewModel.TodayReadings) or nameof(HomeViewModel.TodayTorahPortion))
            Readings.Refresh(ViewModel);
    }

    private void OnReadingEditionChanged() => DispatcherQueue.TryEnqueue(() =>
    {
        if (IsLoaded) Readings.Refresh(ViewModel);
    });

    private void OnReadingTypographyChanged() => DispatcherQueue.TryEnqueue(() =>
    {
        if (IsLoaded) Readings.RefreshTypography();
    });

    private void OnOptionsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(SettingsViewModel.ShowTodayFeast)
            or nameof(SettingsViewModel.ShowTodayIntention)
            or nameof(SettingsViewModel.ShowTodayTorahPortion)
            or nameof(SettingsViewModel.SelectedFeastCalendar)
            or nameof(SettingsViewModel.SelectedEasternPascha))
        {
            ViewModel.RefreshToday();
        }
    }

    private void RefreshForClock()
    {
        var today = DateOnly.FromDateTime(DateTime.Today);
        // A reader browsing a date keeps it. A page that followed today advances at midnight
        // and after returning from sleep, including a change in the device's time zone.
        if (today != _lastLocalDate && ViewModel.SelectedDate == _lastLocalDate)
            ViewModel.SelectTodayCommand.Execute(null);
        _lastLocalDate = today;
        ViewModel.RefreshToday();
    }

    private void OnTodayDateFlyoutOpened(object sender, object e)
    {
        _updatingTodayCalendar = true;
        try
        {
            var selected = new DateTimeOffset(ViewModel.SelectedDate.ToDateTime(TimeOnly.MinValue));
            TodayCalendar.SelectedDates.Clear();
            TodayCalendar.SelectedDates.Add(selected);
            TodayCalendar.SetDisplayDate(selected);
        }
        finally { _updatingTodayCalendar = false; }
    }

    private void OnTodayCalendarDateChanged(CalendarView sender, CalendarViewSelectedDatesChangedEventArgs args)
    {
        if (_updatingTodayCalendar) return;
        if (args.AddedDates.Count > 0) ViewModel.SelectedTodayDate = args.AddedDates[0];
        TodayDateFlyout.Hide();
    }

    private void OnSelectToday(object sender, RoutedEventArgs e)
    {
        ViewModel.SelectTodayCommand.Execute(null);
        TodayDateFlyout.Hide();
    }
}
