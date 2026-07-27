using System.Runtime.CompilerServices;

// Lets Prosary.Tests call PrayerEngine's internal calendar-injectable BuildCustomDevotionSteps
// overload (see PrayerEngine.cs) to exercise the Eastertide/seasonal-antiphon branches
// deterministically, and read the internal per-language translation tables.
[assembly: InternalsVisibleTo("Prosary.Tests")]
