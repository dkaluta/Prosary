namespace Prosary.Localization;

/// <summary>Authored content owns creed availability and its sourced procession clause.</summary>
public sealed record CreedPolicy(bool? ApostlesCreed = null, string? Filioque = null, string? Rite = null);
