using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public sealed class DesktopPrayerLibraryTests
{
    [Fact]
    public void GalleryCreatesSavedCopiesWithoutChangingAnotherDevotionsDefault()
    {
        var rosary = new Prayer { Name = "Rosary", Kind = PrayerKind.Rosary, IsDefault = true };
        var angelus = new DesktopGalleryItem("angelus", "Angelus", "", "");
        var created = DesktopPrayerLibrary.Create(angelus, [rosary]);
        Assert.Equal(PrayerKind.Custom, created.Kind);
        Assert.Equal("angelus", created.CustomDevotionId);
        Assert.True(created.IsDefault);
        Assert.True(rosary.IsDefault);
        Assert.NotEqual(rosary.Id, created.Id);
        var second = DesktopPrayerLibrary.Create(angelus, [rosary, created]);
        Assert.False(second.IsDefault);
        Assert.Equal("Angelus (2)", second.Name);
        Assert.NotEqual(created.Id, second.Id);
    }

    [Fact]
    public void RosaryAndJesusPrayerTemplatesKeepTheirStructuralKinds()
    {
        foreach (var (id, kind) in new[] { ("rosary", PrayerKind.Rosary), ("jesusPrayer", PrayerKind.JesusPrayer) })
        {
            var prayer = DesktopPrayerLibrary.Create(new DesktopGalleryItem(id, id, "", ""), []);
            Assert.Equal(kind, prayer.Kind);
            Assert.Null(prayer.CustomDevotionId);
            Assert.Empty(prayer.Reminders);
            Assert.Equal(LanguageCatalog.DefaultSentinel, prayer.LanguageCode);
        }
    }

    [Fact]
    public void DuplicateHasOwnIdentityOptionsAndDisabledReminderCopies()
    {
        var source = new Prayer
        {
            Name = "My Angelus", Kind = PrayerKind.Custom, CustomDevotionId = "angelus",
            IsDefault = true, LanguageCode = "he", VariantId = "traditional", DayIndex = 2,
            CustomOptions = new() { ["response"] = "short" },
            Reminders = [new PrayerReminder(12)]
        };
        var copy = DesktopPrayerLibrary.Duplicate(source, [source.Name]);
        Assert.NotEqual(source.Id, copy.Id);
        Assert.False(copy.IsDefault);
        Assert.Equal(source.LanguageCode, copy.LanguageCode);
        Assert.Equal(source.VariantId, copy.VariantId);
        Assert.Equal(source.DayIndex, copy.DayIndex);
        Assert.NotSame(source.CustomOptions, copy.CustomOptions);
        copy.CustomOptions["response"] = "long";
        Assert.Equal("short", source.CustomOptions["response"]);
        Assert.NotEqual(source.Reminders[0].Id, copy.Reminders[0].Id);
        Assert.False(copy.Reminders[0].IsEnabled);
        Assert.True(source.Reminders[0].IsEnabled);
    }

    [Fact]
    public void NamingRetainsAuthoredUnicodeAndAvoidsCaseInsensitiveCollisions()
    {
        Assert.Equal("תפילה (3)", DesktopPrayerLibrary.UniqueName("תפילה", ["תפילה", "תפילה (2)"]));
        Assert.Equal("Prayer (2)", DesktopPrayerLibrary.UniqueName("Prayer", ["PRAYER"]));
        Assert.Equal("Молитва", DesktopPrayerLibrary.UniqueName("Молитва", ["Prayer"]));
    }
}
