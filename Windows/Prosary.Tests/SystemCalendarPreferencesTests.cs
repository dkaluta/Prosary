using System.Globalization;
using Prosary.Controls;
using Xunit;

namespace Prosary.Tests;

public class SystemCalendarPreferencesTests
{
    [Theory]
    [InlineData("en-US", Windows.Globalization.DayOfWeek.Sunday)]
    [InlineData("en-GB", Windows.Globalization.DayOfWeek.Monday)]
    public void SystemRegionControlsFirstWeekday(string region, Windows.Globalization.DayOfWeek firstDay)
    {
        Assert.Equal(firstDay, SystemCalendarPreferences.Resolve(new CultureInfo(region)).FirstDayOfWeek);
    }

    [Fact]
    public void ManualRegionalWeekStartAndHebrewCalendarArePreserved()
    {
        var culture = (CultureInfo)new CultureInfo("he-IL").Clone();
        culture.DateTimeFormat.Calendar = new HebrewCalendar();
        culture.DateTimeFormat.FirstDayOfWeek = DayOfWeek.Saturday;
        var preferences = SystemCalendarPreferences.Resolve(culture);
        Assert.Equal("HebrewCalendar", preferences.CalendarIdentifier);
        Assert.Equal(Windows.Globalization.DayOfWeek.Saturday, preferences.FirstDayOfWeek);
    }
}
