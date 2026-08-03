using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.ViewModels;
using Prosary.Views;

namespace Prosary.Services;

/// <summary>Where opening a directory entry leads.</summary>
public enum LaunchTargetKind
{
    Rosary,
    Custom,
    JesusPrayer,
}

/// <summary>One launchable devotion for the Categories/Search pages — mirrors iOS's
/// DevotionDirectory so nothing devotion-specific is hardcoded in either page.</summary>
public sealed record DevotionListing(
    string Id,
    string Title,
    string IconGlyph,
    // Lowercase category labels from the manifest; the Jesus Prayer, having no bundle,
    // carries its tags here.
    IReadOnlyList<string> Tags,
    LaunchTargetKind Target,
    string? BundleId = null)
{
    public void Launch()
    {
        switch (Target)
        {
            case LaunchTargetKind.Rosary:
                Router.Navigate<RosaryPresetPickerPage>();
                break;
            case LaunchTargetKind.Custom:
                Router.Navigate<CustomDevotionFlowPage>(new CustomDevotionFlowParams(null, BundleId!));
                break;
            case LaunchTargetKind.JesusPrayer:
                Router.Navigate<JesusPrayerSetupPage>();
                break;
        }
    }
}

public static class DevotionDirectory
{
    public static IReadOnlyList<DevotionListing> All()
    {
        var listings = new List<DevotionListing>
        {
            new(
                "rosary",
                PrayerKind.Rosary.DisplayName(),
                "\uEA3A", // CircleRing — HomePage's Rosary glyph
                PrayerPackStore.Info("rosary")?.Tags ?? ["marian"],
                LaunchTargetKind.Rosary),
        };
        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            if (PrayerPackStore.Info(bundleId) is not { } info) continue;
            listings.Add(new DevotionListing(
                bundleId,
                info.LocalizedDisplayName,
                info.IconGlyph ?? HomeViewModel.GlyphForSystemName(info.IconSystemName),
                info.Tags,
                LaunchTargetKind.Custom,
                bundleId));
        }
        listings.Add(new DevotionListing(
            "jesusPrayer",
            PrayerKind.JesusPrayer.DisplayName(),
            "\uEB52", // HeartFill — HomePage's Jesus Prayer glyph
            ["eastern", "meditative"],
            LaunchTargetKind.JesusPrayer));
        return listings;
    }
}
