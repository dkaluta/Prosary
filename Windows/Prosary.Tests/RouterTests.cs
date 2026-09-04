using Prosary.Navigation;
using Xunit;

namespace Prosary.Tests;

public class RouterTests
{
    private sealed class FirstPageMarker { }
    private sealed class SecondPageMarker { }
    private sealed record RouteParameter(Guid Id, string Kind);

    [Fact]
    public void IsDuplicateNavigation_SamePageAndNullParameter_IsDuplicate()
    {
        Assert.True(Router.IsDuplicateNavigation(
            typeof(FirstPageMarker),
            null,
            typeof(FirstPageMarker),
            null));
    }

    [Fact]
    public void IsDuplicateNavigation_SamePageAndEqualValueParameter_IsDuplicate()
    {
        var id = Guid.NewGuid();

        Assert.True(Router.IsDuplicateNavigation(
            typeof(FirstPageMarker),
            new RouteParameter(id, "rosary"),
            typeof(FirstPageMarker),
            new RouteParameter(id, "rosary")));
    }

    [Fact]
    public void IsDuplicateNavigation_SamePageAndDifferentParameter_IsNotDuplicate()
    {
        Assert.False(Router.IsDuplicateNavigation(
            typeof(FirstPageMarker),
            new RouteParameter(Guid.NewGuid(), "rosary"),
            typeof(FirstPageMarker),
            new RouteParameter(Guid.NewGuid(), "rosary")));
    }

    [Fact]
    public void IsDuplicateNavigation_DifferentPageAndEqualParameter_IsNotDuplicate()
    {
        var parameter = new RouteParameter(Guid.NewGuid(), "rosary");

        Assert.False(Router.IsDuplicateNavigation(
            typeof(FirstPageMarker),
            parameter,
            typeof(SecondPageMarker),
            parameter));
    }
}
