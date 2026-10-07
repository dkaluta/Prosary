using Prosary.Persistence;

namespace Prosary.Models;

/// <summary>Session-only mystery choices. The saved configuration remains the resume gate.</summary>
public static class RosarySessionNavigation
{
    public static RosaryOptions Options(RosaryOptions original, MysteryGroup group, int? order) => original with
    {
        MysterySelectionMode = order is not null && (original.MysterySelectionMode is MysterySelectionMode.SingleMystery or MysterySelectionMode.ChooseOnLaunch)
            ? MysterySelectionMode.SingleMystery : MysterySelectionMode.Specific,
        SpecificMysteryGroup = group,
        SpecificMysteryOrder = order is { } number ? Math.Clamp(number, 1, 5) : 1,
        // Preserve the original requested range; the effective start clips it at the fifth mystery.
        SpecificMysteryCount = order is null ? original.SpecificMysteryCount : Math.Clamp(original.SpecificMysteryCount, 1, 5),
    };

    public static string Signature(RosaryOptions original, MysteryGroup? group = null, int? order = null)
    {
        var signature = PrayerRunSignatures.Rosary(original);
        if (group is not { } chosen) return signature;
        signature += $"|navigation-group:{chosen.ToString().ToLowerInvariant()}";
        return order is { } number ? signature + $"|navigation-order:{number}" : signature;
    }

    public static bool TryRestore(RosaryOptions original, PrayerRunState saved,
        out RosaryOptions options, out MysteryGroup? group, out int? order)
    {
        options = original;
        group = null;
        order = null;
        if (saved.RosaryNavigationGroup is null && saved.RosaryNavigationOrder is null)
            return saved.ConfigurationSignature == Signature(original);
        var parsed = saved.RosaryNavigationGroup switch
        {
            "joyful" => MysteryGroup.Joyful,
            "sorrowful" => MysteryGroup.Sorrowful,
            "glorious" => MysteryGroup.Glorious,
            "luminous" => MysteryGroup.Luminous,
            _ => (MysteryGroup?)null,
        };
        if (parsed is null || saved.RosaryNavigationOrder is < 1 or > 5) return false;
        if (saved.ConfigurationSignature != Signature(original, parsed, saved.RosaryNavigationOrder)) return false;
        group = parsed;
        order = saved.RosaryNavigationOrder;
        options = Options(original, group.Value, order);
        return true;
    }
}
