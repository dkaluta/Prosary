using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class SearchCategoryTests
{
    private static DevotionListing Local(string id, string title, params string[] tags) =>
        new(id, title, "", tags, LaunchTargetKind.Custom, id);

    [Fact]
    public async Task CategoryAndTextBothConstrainAvailablePrayers()
    {
        var local = new[] { Local("marian", "Morning prayer", "marian"), Local("daily", "Morning prayer", "daily") };
        var vm = new SearchViewModel(() => local);
        await vm.LoadAsync();
        vm.SelectedCategory = vm.Categories.Single(category => category.Id == "marian");
        vm.SearchText = "morning";
        Assert.Equal("marian", Assert.Single(vm.LocalMatches).Id);
        vm.SearchText = "absent";
        Assert.Empty(vm.LocalMatches);
        Assert.True(vm.HasNoMatches);
    }

    [Fact]
    public async Task ReturningToSearchRefreshesNewlyInstalledPrayersAndCategories()
    {
        var local = new List<DevotionListing> { Local("local", "Prayer", "daily") };
        var vm = new SearchViewModel(() => local);
        await vm.LoadAsync();
        Assert.Single(vm.LocalMatches);
        local.Add(Local("installed", "Downloaded prayer", "eastern"));
        await vm.LoadAsync();
        Assert.Contains(vm.Categories, category => category.Id == "eastern");
        vm.SearchText = "downloaded";
        Assert.Equal("installed", Assert.Single(vm.LocalMatches).Id);
    }

    [Fact]
    public async Task RefreshRetainsPickerSelectionAndUntaggedPrayersRemainBrowsable()
    {
        var local = new List<DevotionListing> { Local("untagged", "Prayer"), Local("daily", "Daily", " Daily ") };
        var vm = new SearchViewModel(() => local);
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
