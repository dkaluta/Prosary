using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>Pins the prayers.prosary.app /index.json contract (prosaryRepository: 1) without a
/// network — mirrors iOS's RepositoryClientTests / Android's RepositoryClientTest.</summary>
public class RepositoryClientTests
{
    private const string Fixture = """
        {"prosaryRepository": 1, "bundles": [
          {"id": "repo.dkaluta.kyrie", "name": "Kyrie", "author": "dkaluta",
           "languages": ["la", "en"], "tags": ["short"],
           "description": "A one-minute devotion.", "file": "/api/download/repo.dkaluta.kyrie"}
        ]}
        """;

    [Fact]
    public void ParsesTheVersionedCatalog()
    {
        var bundles = RepositoryClient.ParseCatalog(Fixture);
        Assert.Single(bundles);
        Assert.Equal("repo.dkaluta.kyrie", bundles[0].Id);
        Assert.Equal("dkaluta", bundles[0].Author);
        Assert.Equal(["la", "en"], bundles[0].Languages);
        Assert.Equal(["short"], bundles[0].Tags);
        Assert.Equal("/api/download/repo.dkaluta.kyrie", bundles[0].File);
    }

    [Fact]
    public void RejectsANewerCatalogVersion()
    {
        Assert.Throws<RepositoryClient.UnsupportedCatalogException>(
            () => RepositoryClient.ParseCatalog("""{"prosaryRepository": 2, "bundles": []}"""));
    }
}
