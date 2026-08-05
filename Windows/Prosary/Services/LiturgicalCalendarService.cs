using Prosary.Models;
using Microsoft.UI;
using Windows.UI;

namespace Prosary.Services;

/// <summary>
/// Resolves "today's mysteries" per the traditional weekday assignment:
/// Mon/Sat Joyful, Tue/Fri Sorrowful, Wed Glorious, Thu Luminous, and on Sundays the
/// mysteries proper to the liturgical season (Joyful in Advent/Christmas, Sorrowful in
/// Lent, Glorious otherwise).
/// </summary>
public sealed class LiturgicalCalendarService
{
    public MysteryGroup GetMysteryGroup(DateOnly date)
    {
        return date.DayOfWeek switch
        {
            DayOfWeek.Monday or DayOfWeek.Saturday => MysteryGroup.Joyful,
            DayOfWeek.Tuesday or DayOfWeek.Friday => MysteryGroup.Sorrowful,
            DayOfWeek.Wednesday => MysteryGroup.Glorious,
            DayOfWeek.Thursday => MysteryGroup.Luminous,
            DayOfWeek.Sunday => GetMysteryGroupForSunday(date),
            _ => MysteryGroup.Joyful
        };
    }

    public MysteryGroup GetMysteryGroupForToday() => GetMysteryGroup(DateOnly.FromDateTime(DateTime.Today));

    /// <summary>The Marian antiphon traditionally used during the current liturgical season.</summary>
    public MarianAntiphonOption GetSeasonalMarianAntiphon(DateOnly date)
    {
        return GetSeason(date) switch
        {
            LiturgicalSeason.Advent or LiturgicalSeason.Christmas => MarianAntiphonOption.AlmaRedemptorisMater,
            LiturgicalSeason.Lent => MarianAntiphonOption.AveReginaCaelorum,
            LiturgicalSeason.EasterSeason => MarianAntiphonOption.ReginaCaeli,
            _ => MarianAntiphonOption.SalveRegina
        };
    }

    public MarianAntiphonOption GetSeasonalMarianAntiphonForToday() =>
        GetSeasonalMarianAntiphon(DateOnly.FromDateTime(DateTime.Today));

    /// <summary>True from Easter Sunday through the day before Pentecost, inclusive — used by
    /// <see cref="PrayerEngine"/> to substitute the Regina Caeli for the ordinary Angelus.</summary>
    public bool IsEasterSeason(DateOnly date) => GetSeason(date) == LiturgicalSeason.EasterSeason;

    public bool IsEasterSeasonForToday() => IsEasterSeason(DateOnly.FromDateTime(DateTime.Today));

    /// <summary>True through Lent — the season that strips the Alleluia from the liturgy, and so
    /// from any devotion's step that carries one.</summary>
    public bool IsLent(DateOnly date) => GetSeason(date) == LiturgicalSeason.Lent;

    public bool IsLentForToday() => IsLent(DateOnly.FromDateTime(DateTime.Today));

    /// <summary>The traditional liturgical color for the day, for use as an accent/banner color.</summary>
    public Color GetSeasonColor(DateOnly date)
    {
        var easter = ComputeEasterSunday(date.Year);
        if (date == easter.AddDays(49))
        {
            return ColorFromHex("#B22222"); // Pentecost: red
        }

        return GetSeason(date) switch
        {
            LiturgicalSeason.Advent or LiturgicalSeason.Lent => ColorFromHex("#6A3E8E"), // violet
            LiturgicalSeason.Christmas or LiturgicalSeason.EasterSeason => ColorFromHex("#B8860B"), // gold/white
            _ => ColorFromHex("#2E7D32") // green: Ordinary Time
        };
    }

    public Color GetSeasonColorForToday() => GetSeasonColor(DateOnly.FromDateTime(DateTime.Today));

    private static Color ColorFromHex(string hex)
    {
        var value = Convert.ToUInt32(hex.TrimStart('#'), 16);
        return Color.FromArgb(0xFF, (byte)(value >> 16), (byte)(value >> 8), (byte)value);
    }

    private static MysteryGroup GetMysteryGroupForSunday(DateOnly date)
    {
        var season = GetSeason(date);
        return season switch
        {
            LiturgicalSeason.Advent => MysteryGroup.Joyful,
            LiturgicalSeason.Christmas => MysteryGroup.Joyful,
            LiturgicalSeason.Lent => MysteryGroup.Sorrowful,
            _ => MysteryGroup.Glorious
        };
    }

    private enum LiturgicalSeason { Advent, Christmas, Lent, EasterSeason, Other }

    private static LiturgicalSeason GetSeason(DateOnly date)
    {
        var year = date.Year;
        var easter = ComputeEasterSunday(year);
        var ashWednesday = easter.AddDays(-46);

        if (date >= ashWednesday && date < easter)
        {
            return LiturgicalSeason.Lent;
        }

        var pentecost = easter.AddDays(49);
        if (date >= easter && date < pentecost)
        {
            return LiturgicalSeason.EasterSeason;
        }

        var adventStart = FirstSundayOnOrAfter(new DateOnly(year, 11, 27));
        var christmas = new DateOnly(year, 12, 25);
        if (date >= adventStart && date < christmas)
        {
            return LiturgicalSeason.Advent;
        }

        // Christmas season runs from Dec 25 through the Baptism of the Lord
        // (approximated as the first Sunday on/after Jan 7), spanning new year's day.
        if (date >= christmas && date < FirstSundayOnOrAfter(new DateOnly(year + 1, 1, 7)))
        {
            return LiturgicalSeason.Christmas;
        }

        if (date < christmas && date < FirstSundayOnOrAfter(new DateOnly(year, 1, 7))
                              && date >= new DateOnly(year - 1, 12, 25))
        {
            return LiturgicalSeason.Christmas;
        }

        return LiturgicalSeason.Other;
    }

    private static DateOnly FirstSundayOnOrAfter(DateOnly date)
    {
        var offset = ((int)DayOfWeek.Sunday - (int)date.DayOfWeek + 7) % 7;
        return date.AddDays(offset);
    }

    /// <summary>Anonymous Gregorian algorithm (Meeus/Jones/Butcher).</summary>
    private static DateOnly ComputeEasterSunday(int year)
    {
        var a = year % 19;
        var b = year / 100;
        var c = year % 100;
        var d = b / 4;
        var e = b % 4;
        var f = (b + 8) / 25;
        var g = (b - f + 1) / 3;
        var h = (19 * a + b - d - g + 15) % 30;
        var i = c / 4;
        var k = c % 4;
        var l = (32 + 2 * e + 2 * i - h - k) % 7;
        var m = (a + 11 * h + 22 * l) / 451;
        var month = (h + l - 7 * m + 114) / 31;
        var day = (h + l - 7 * m + 114) % 31 + 1;
        return new DateOnly(year, month, day);
    }
}
