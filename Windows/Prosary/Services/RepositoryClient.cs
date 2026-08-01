using System.Net.Http;
using System.Text.Json;

namespace Prosary.Services;

/// <summary>One catalog entry from prayers.prosary.app/index.json. <see cref="Id"/> is always
/// <c>repo.&lt;username&gt;.&lt;name&gt;</c> — the prefix the Favorites rows key their
/// "Repository" tag on.</summary>
public sealed record RepositoryBundle(
    string Id,
    string Name,
    string Author,
    List<string> Languages,
    List<string> Tags,
    string Description,
    // Same-origin download path ("/api/download/<id>") — downloads count server-side.
    string File);

/// <summary>Fetches the prayers.prosary.app catalog (the versioned /index.json contract — see
/// Shared/ARCHITECTURE.md § Content bundles) and downloads bundles through the same-origin
/// download path, so server-side counting keeps working and the storage behind it can change
/// without breaking installed apps.</summary>
public static class RepositoryClient
{
    public const string BaseUrl = "https://prayers.prosary.app";

    private static readonly HttpClient Http = new();
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private sealed record Catalog(int ProsaryRepository, List<RepositoryBundle>? Bundles);

    public sealed class UnsupportedCatalogException()
        : Exception("The repository uses a newer catalog format — update Prosary to browse it.");

    /// <summary>Split out from the fetch so tests can pin the contract without a network.</summary>
    public static IReadOnlyList<RepositoryBundle> ParseCatalog(string json)
    {
        var catalog = JsonSerializer.Deserialize<Catalog>(json, JsonOptions)
            ?? throw new UnsupportedCatalogException();
        if (catalog.ProsaryRepository != 1) throw new UnsupportedCatalogException();
        return catalog.Bundles ?? [];
    }

    public static async Task<IReadOnlyList<RepositoryBundle>> FetchCatalogAsync()
        => ParseCatalog(await Http.GetStringAsync($"{BaseUrl}/index.json"));

    public static async Task<byte[]> DownloadBundleAsync(RepositoryBundle bundle)
        => await Http.GetByteArrayAsync(BaseUrl + bundle.File);
}
