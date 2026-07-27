namespace Prosary.Models;

public enum EternalRestPlacement
{
    None,

    /// <summary>Pray "Eternal rest grant unto them, O Lord" after the Glory Be of every decade.</summary>
    AfterEachDecade,

    /// <summary>Pray it once, near the end, before the closing prayers.</summary>
    AtEndOnly
}

public static class EternalRestPlacementExtensions
{
    public static string DisplayName(this EternalRestPlacement placement) => placement switch
    {
        EternalRestPlacement.None => "Don't Include",
        EternalRestPlacement.AfterEachDecade => "After Each Decade",
        EternalRestPlacement.AtEndOnly => "Once, Near the End",
        _ => throw new ArgumentOutOfRangeException(nameof(placement))
    };
}
