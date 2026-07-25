using System.Runtime.CompilerServices;

// Lets Prosary.Tests call AngelusEngine's internal date-injectable BuildSteps overload (see
// AngelusEngine.cs) to exercise both the ordinary/Easter-season branches deterministically.
[assembly: InternalsVisibleTo("Prosary.Tests")]
