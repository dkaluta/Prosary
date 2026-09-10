using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class SearchCategoryTests
{
    private static DevotionListing Local(string id, string title, params string[] tags) =>
        new(id, title, "", tags, LaunchTargetKind.Custom, id);
    private static RepositoryBundle Community(string id, string title, params string[] tags) =>
        new(id, title, "Author", ["en"], tags.ToList(), "Description", "/fixture");

    [Fact]
    public async Task CategoryAndTextFilterBothCatalogsAndHideInstalledCommunityCopies()
    {
        var local = new[] { Local("local-marian", "Morning prayer", "marian"), Local("local-daily", "Morning prayer", "daily") };
        IReadOnlyList<RepositoryBundle> community = [Community("remote-marian", "Morning prayer", "marian"),
            Community("remote-daily", "Morning prayer", "daily"), Community("installed", "Morning prayer", "marian")];
        var vm = new SearchViewModel(() => local, () => Task.FromResult(community), () => ["installed"]);
        await vm.LoadAsync();
        vm.SelectedCategory = vm.Categories.Single(category => category.Id == "marian");
        vm.SearchText = "morning";
        Assert.Equal("local-marian", Assert.Single(vm.LocalMatches).Id);
        Assert.Equal("remote-marian", Assert.Single(vm.CommunityMatches).Bundle.Id);
        vm.SearchText = "absent";
        Assert.Empty(vm.LocalMatches);
        Assert.Empty(vm.CommunityMatches);
        Assert.True(vm.HasNoMatches);
    }

    [Fact]
    public async Task LocalCategoriesAreUsableBeforeTheCommunityRequestFinishes()
    {
        var pending = new TaskCompletionSource<IReadOnlyList<RepositoryBundle>>();
        var vm = new SearchViewModel(() => [Local("local", "Prayer", "daily")], () => pending.Task, () => []);
        var loading = vm.LoadAsync();
        Assert.Single(vm.LocalMatches);
        Assert.Contains(vm.Categories, category => category.Id == "daily");
        Assert.True(vm.IsLoadingCatalog);
        pending.SetResult([Community("remote", "Prayer", "eastern")]);
        await loading;
        Assert.Contains(vm.Categories, category => category.Id == "eastern");
        Assert.False(vm.IsLoadingCatalog);
    }

    [Fact]
    public async Task OfflineLocalSearchWorksAndCommunityCanRetryOnReturn()
    {
        var attempts = 0;
        var vm = new SearchViewModel(() => [Local("local", "Prayer", "daily")], () =>
        {
            attempts++;
            return attempts == 1
                ? Task.FromException<IReadOnlyList<RepositoryBundle>>(new IOException("offline"))
                : Task.FromResult<IReadOnlyList<RepositoryBundle>>([Community("remote", "Prayer", "eastern")]);
        }, () => []);
        await vm.LoadAsync();
        Assert.Single(vm.LocalMatches);
        Assert.Empty(vm.CommunityMatches);
        await vm.LoadAsync();
        Assert.Equal(2, attempts);
        Assert.Single(vm.CommunityMatches);
    }

    [Fact]
    public async Task RefreshRetainsPickerSelectionAndUntaggedPrayersRemainBrowsable()
    {
        var local = new List<DevotionListing> { Local("untagged", "Prayer"), Local("daily", "Daily", " Daily ") };
        var vm = new SearchViewModel(() => local, () => Task.FromResult<IReadOnlyList<RepositoryBundle>>([]), () => []);
        await vm.LoadAsync();
        var selected = vm.Categories.Single(category => category.Id == "other");
        vm.SelectedCategory = selected;
        local.Add(Local("second", "Another prayer"));
        vm.RefreshLocal();
        Assert.Same(selected, vm.SelectedCategory);
        Assert.Equal(2, vm.LocalMatches.Count);
        Assert.Contains(vm.Categories, category => category.Id == "daily");
    }
}
