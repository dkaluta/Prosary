using System.Globalization;
using Prosary.Localization;

namespace Prosary.Services;

/// <summary>Installed package metadata wins; unpackaged builds use their assembly metadata.</summary>
public static class AppBuildInfo
{
    public static string AboutText
    {
        get
        {
            var version = ResolveVersion(ReadPackageVersion,
                () => typeof(AppBuildInfo).Assembly.GetName().Version ?? new Version());
            var parts = DisplayParts(version);
            return string.Format(Loc.Tr("AboutVersion", "Version {0} ({1})"), parts.Version, parts.Build);
        }
    }

    private static Version ReadPackageVersion()
    {
        var version = Windows.ApplicationModel.Package.Current.Id.Version;
        return new Version(version.Major, version.Minor, version.Build, version.Revision);
    }

    internal static Version ResolveVersion(Func<Version> packageVersion, Func<Version> assemblyVersion)
    {
        try { return packageVersion(); }
        catch { return assemblyVersion(); }
    }

    internal static (string Version, string Build) DisplayParts(Version version) =>
        (string.Create(CultureInfo.InvariantCulture,
            $"{version.Major}.{version.Minor}.{Math.Max(0, version.Build)}"),
            Math.Max(0, version.Revision).ToString(CultureInfo.InvariantCulture));
}
