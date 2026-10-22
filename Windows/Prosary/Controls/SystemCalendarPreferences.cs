using System.Globalization;
using Microsoft.UI.Xaml.Controls;

namespace Prosary.Controls;

/// System region owns display preferences; selected dates retain their civil event identity.
public static class SystemCalendarPreferences
{
    public static void Apply(CalendarView picker)
    {
        var preferences = Resolve(CultureInfo.CurrentCulture);
        picker.FirstDayOfWeek = preferences.FirstDayOfWeek;
        picker.CalendarIdentifier = preferences.CalendarIdentifier;
    }

    public static (Windows.Globalization.DayOfWeek FirstDayOfWeek, string CalendarIdentifier) Resolve(CultureInfo culture)
    {
        var format = culture.DateTimeFormat;
        var identifier = format.Calendar switch
        {
            HebrewCalendar => "HebrewCalendar",
            HijriCalendar => "HijriCalendar",
            UmAlQuraCalendar => "UmAlQuraCalendar",
            JapaneseCalendar => "JapaneseCalendar",
            TaiwanCalendar => "TaiwanCalendar",
            KoreanCalendar => "KoreanCalendar",
            ThaiBuddhistCalendar => "ThaiCalendar",
            PersianCalendar => "PersianCalendar",
            JulianCalendar => "JulianCalendar",
            _ => "GregorianCalendar"
        };
        return ((Windows.Globalization.DayOfWeek)(int)format.FirstDayOfWeek, identifier);
    }
}
