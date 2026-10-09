using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class AppBuildInfoTests
{
    [Fact]
    public void InstalledPackageVersionTakesPrecedenceOverAssemblyVersion()
    {
        var actual = AppBuildInfo.ResolveVersion(() => new Version(1, 20, 4, 7),
            () => throw new InvalidOperationException("The fallback should not be read."));

        Assert.Equal(new Version(1, 20, 4, 7), actual);
    }

    [Fact]
    public void UnpackagedProcessUsesAssemblyVersionWithoutFailingAbout()
    {
        var actual = AppBuildInfo.ResolveVersion(
            () => throw new InvalidOperationException("The process has no package identity."),
            () => new Version(0, 20, 4, 0));

        Assert.Equal(new Version(0, 20, 4, 0), actual);
    }

    [Theory]
    [InlineData(0, 20, 4, 0, "0.20.4", "0")]
    [InlineData(1, 20, 4, 7, "1.20.4", "7")]
    public void AboutSeparatesTheInstalledVersionAndBuildRevision(int major, int minor,
        int patch, int revision, string expectedVersion, string expectedBuild)
    {
        var actual = AppBuildInfo.DisplayParts(new Version(major, minor, patch, revision));

        Assert.Equal(expectedVersion, actual.Version);
        Assert.Equal(expectedBuild, actual.Build);
    }
}
