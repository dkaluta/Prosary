using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class TodayNavigationTests
{
    [Theory]
    [InlineData("roman1962")]
    [InlineData("ugcc")]
    [InlineData("syriac")]
    [InlineData("maronite")]
    public void OtherRitesUseCivilDayWithoutBorrowingRomanSeasons(string calendar)
    {
        var previous = TodayInfoStore.SelectedCalendarId;
        try
        {
            TodayInfoStore.SelectedCalendarId = calendar;
            var day = TodayInfoStore.LiturgicalDay(new DateOnly(2026, 9, 7));
            Assert.False(day.UsesRomanSeason);
            Assert.True(day.IsVisible);
            Assert.Equal("Day 7 of September", day.Localized("en"));
            Assert.Equal("יום 7 בחודש ספטמבר", day.Localized("he"));
            foreach (var language in new[] { "ar", "ru", "tl", "fr", "it" })
                Assert.NotEqual(day.Localized("en"), day.Localized(language));
        }
        finally { TodayInfoStore.SelectedCalendarId = previous; }
    }

    [Theory]
    [InlineData("lpj")]
    [InlineData("roman")]
    [InlineData("roman1962")]
    [InlineData("ugcc")]
    [InlineData("syriac")]
    [InlineData("maronite")]
    public void SundaysHideOnlyTheSupplementalDay(string calendar)
    {
        var previous = TodayInfoStore.SelectedCalendarId;
        try
        {
            TodayInfoStore.SelectedCalendarId = calendar;
            Assert.False(TodayInfoStore.LiturgicalDay(new DateOnly(2026, 9, 6)).IsVisible);
            Assert.NotNull(TodayInfoStore.Feast(new DateOnly(2026, 9, 6)));
            if (calendar is "lpj" or "roman")
                Assert.Contains("Ordinary Time", TodayInfoStore.LiturgicalDay(new DateOnly(2026, 9, 7)).Localized("en"));
        }
        finally { TodayInfoStore.SelectedCalendarId = previous; }
    }

    [Fact]
    public void BrowsingUsesTheSelectedCivilDateAndCanReturnToToday()
    {
        var previousCalendar = TodayInfoStore.SelectedCalendarId;
        var previousFeast = AppSettings.ShowTodayFeast;
        var previousIntention = AppSettings.ShowTodayIntention;
        var previousTorah = AppSettings.ShowTodayTorahPortion;
        try
        {
            TodayInfoStore.SelectedCalendarId = "roman";
            AppSettings.SetShowTodayFeast(true);
            AppSettings.SetShowTodayIntention(true);
            AppSettings.SetShowTodayTorahPortion(true);
            var vm = new HomeViewModel(new EmptyPresetStore(), new LiturgicalCalendarService());
            // Keep the picker's civil date even with an offset near the international date line.
            vm.SelectedTodayDate = new DateTimeOffset(2026, 12, 31, 0, 0, 0, TimeSpan.FromHours(14));
            Assert.Equal(new DateOnly(2026, 12, 31), vm.SelectedDate);
            Assert.Equal(TodayInfoStore.Intention(vm.SelectedDate), vm.MonthIntention);
            vm.TomorrowCommand.Execute(null);
            Assert.Equal(new DateOnly(2027, 1, 1), vm.SelectedDate);
            Assert.Equal(TodayInfoStore.Feast(vm.SelectedDate), vm.TodayFeast);
            Assert.Equal(TodayInfoStore.Intention(vm.SelectedDate), vm.MonthIntention);
            Assert.Equal(TodayInfoStore.Readings(vm.SelectedDate), vm.TodayReadings);
            Assert.Equal(TodayInfoStore.WeeklyTorahPortion(vm.SelectedDate), vm.TodayTorahPortion);
            vm.YesterdayCommand.Execute(null);
            Assert.Equal(new DateOnly(2026, 12, 31), vm.SelectedDate);
            vm.SelectTodayCommand.Execute(null);
            Assert.True(vm.IsSelectedDateToday);
            vm.SelectedTodayDate = vm.MinimumTodayDate;
            Assert.False(vm.YesterdayCommand.CanExecute(null));
            vm.SelectedTodayDate = vm.MaximumTodayDate;
            Assert.False(vm.TomorrowCommand.CanExecute(null));
            Assert.False(vm.ShowsTodayTorahPortion);
        }
        finally
        {
            TodayInfoStore.SelectedCalendarId = previousCalendar;
            AppSettings.SetShowTodayFeast(previousFeast);
            AppSettings.SetShowTodayIntention(previousIntention);
            AppSettings.SetShowTodayTorahPortion(previousTorah);
        }
    }

    [Fact]
    public void TorahCycleUsesUpcomingSaturdayAndFestivalReplacementInIsrael()
    {
        var sunday = TodayInfoStore.WeeklyTorahPortion(new DateOnly(2026, 5, 17))!;
        var saturday = TodayInfoStore.WeeklyTorahPortion(new DateOnly(2026, 5, 23))!;
        Assert.Equal(sunday.Saturday, saturday.Saturday);
        Assert.Equal(sunday.Title, saturday.Title);
        Assert.Equal(sunday.LocalizedReadings("en"), saturday.LocalizedReadings("en"));
        Assert.Equal("2026-05-23", saturday.Saturday);
        Assert.Contains("Nasso", saturday.Title);
        Assert.False(saturday.IsHoliday);
        var passover = TodayInfoStore.WeeklyTorahPortion(new DateOnly(2026, 4, 4))!;
        Assert.True(passover.IsHoliday);
        Assert.NotEmpty(passover.Readings!);
        Assert.Null(TodayInfoStore.WeeklyTorahPortion(new DateOnly(2031, 1, 1)));
    }

    [Fact]
    public void ChangingEasternPaschaReloadsFeastAndReadingsWithoutChangingCalendar()
    {
        var oldCalendar = TodayInfoStore.SelectedCalendarId;
        var oldStyle = AppSettings.EasternPaschaStyle;
        try
        {
            TodayInfoStore.SelectedCalendarId = "ugcc";
            AppSettings.SetEasternPaschaStyle("unknown");
            Assert.Equal("julian", AppSettings.EasternPaschaStyle);
            Assert.Contains("Palm", TodayInfoStore.Feast(new DateOnly(2026, 4, 5))!.Title);
            Assert.Contains("Holy Pascha", TodayInfoStore.Feast(new DateOnly(2026, 4, 12))!.Title);
            var september = new DateOnly(2026, 9, 6);
            Assert.Equal(new[] { "2 Corinthians 1:21–2:4", "Matthew 22:1–14" },
                TodayInfoStore.Readings(september).Select(reading => reading.Full));
            AppSettings.SetEasternPaschaStyle("gregorian");
            Assert.Contains("Holy Pascha", TodayInfoStore.Feast(new DateOnly(2026, 4, 5))!.Title);
            Assert.Equal(new[] { "2 Corinthians 4:6–15", "Matthew 22:35–46" },
                TodayInfoStore.Readings(september).Select(reading => reading.Full));
            AppSettings.SetEasternPaschaStyle("julian");
            Assert.Equal("14th Sunday after Pentecost", TodayInfoStore.Feast(september)!.Title);
            Assert.Equal("2 Corinthians 1:21–2:4", TodayInfoStore.Readings(september).First().Full);
        }
        finally
        {
            TodayInfoStore.SelectedCalendarId = oldCalendar;
            AppSettings.SetEasternPaschaStyle(oldStyle);
        }
    }

    [Fact]
    public void DatasetKeysRemainGregorianInAnArabicSystemCulture()
    {
        var oldCulture = System.Globalization.CultureInfo.CurrentCulture;
        var oldCalendar = TodayInfoStore.SelectedCalendarId;
        try
        {
            TodayInfoStore.SelectedCalendarId = "roman";
            var date = new DateOnly(2026, 12, 25);
            System.Globalization.CultureInfo.CurrentCulture = System.Globalization.CultureInfo.GetCultureInfo("ar-SA");
            Assert.Equal("Christmas", TodayInfoStore.Feast(date)?.Title);
            Assert.NotNull(TodayInfoStore.Intention(date));
            Assert.NotNull(TodayInfoStore.WeeklyTorahPortion(date));
        }
        finally
        {
            System.Globalization.CultureInfo.CurrentCulture = oldCulture;
            TodayInfoStore.SelectedCalendarId = oldCalendar;
        }
    }

    private sealed class EmptyPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);
        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
