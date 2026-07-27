using System.Runtime.CompilerServices;

// Lets Prosary.Tests call PrayerEngine's internal date-injectable BuildAngelusSteps overload (see
// PrayerEngine.cs) to exercise both the ordinary/Easter-season branches deterministically.
[assembly: InternalsVisibleTo("Prosary.Tests")]
