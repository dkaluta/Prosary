using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public sealed class ReminderDestinationTests
{
    [Theory]
    [InlineData("prosary://today", "today")]
    [InlineData("prosary://readings", "readings")]
    public void AcceptsSupportedViews(string uri, string section) => Assert.Equal(section, NotificationDestination.Parse(uri)?.Section);

    [Theory]
    [InlineData("https://today")]
    [InlineData("prosary://user@today")]
    [InlineData("prosary://today:80")]
    [InlineData("prosary://today?delete=true")]
    [InlineData("prosary://readings#fragment")]
    [InlineData("prosary://today/elsewhere")]
    [InlineData("prosary://today/elsewhere/..")]
    [InlineData("prosary://prayer/%2E%2E/today")]
    [InlineData("prosary://prayer/../today")]
    [InlineData("prosary://prayer/not-a-uuid")]
    public void RejectsUnexpectedPayloads(string uri) => Assert.Null(NotificationDestination.Parse(uri));

    [Fact]
    public void PrayerLinkRetainsExactSavedIdentity()
    {
        var id = Guid.NewGuid();
        Assert.Equal(id, NotificationDestination.Parse($"prosary://prayer/{id:D}")?.PrayerId);
    }
}
