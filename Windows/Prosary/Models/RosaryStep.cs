using Prosary.Localization;

namespace Prosary.Models;

/// <summary>One prayer "bead" in a fully built Rosary session, ready to display.</summary>
/// <param name="Title">The prominent heading, e.g. "Hail Mary (3 of 10)" or "Our Father".</param>
/// <param name="Subtitle">Muted decade context shown above the title, e.g. "1st Mystery — The Annunciation". Null for steps not tied to a decade.</param>
/// <param name="Body">The full prayer text to display/read.</param>
/// <param name="Mystery">The mystery illustrated on screen for this step, if any.</param>
/// <param name="IsScripture">True only for the mystery-announcement step, whose body is an actual quoted Bible verse rather than a traditional prayer.</param>
/// <param name="IsAntiphon">True only for the Marian antiphon step (the "M" bead in the progress indicator).</param>
/// <param name="DecadeIndex">0-based index of this step's decade, counted globally across every mystery group in the session (0..N-1 for an N-decade session). Null for steps not tied to a decade (opening, antiphon, closing, etc).</param>
/// <param name="HailMaryIndexInDecade">1-10 for the ten Hail Mary steps within a decade; null otherwise.</param>
/// <param name="ImageOverrideKey">Image key for steps not tied to a Mystery but that still want a specific illustration (e.g. "crucifix" for the Sign of the Cross/Apostles' Creed, "madonna_and_child" for the antiphon) instead of the generic placeholder.</param>
public sealed record RosaryStep(
    string Title,
    string? Subtitle,
    string Body,
    Mystery? Mystery = null,
    // Optional acclamation (the Stations' versicle/response) rendered above the body in the
    // regular prayer typeface — a prayer, not part of the reading. Placed after Mystery so
    // existing four-positional-argument call sites keep their meaning.
    string? Acclamation = null,
    bool IsScripture = false,
    // Optional reading aid (v0.7, Gamaliel item 5): the body transliterated into another
    // script; the flow shows a toggle beside the text whenever present.
    string? TransliteratedBody = null,
    bool IsAntiphon = false,
    int? DecadeIndex = null,
    int? HailMaryIndexInDecade = null,
    string? ImageOverrideKey = null)
{
    /// <summary>Titles and subtitles are display chrome rather than prayer text. Normalize them
    /// once at the presentation-model boundary, while leaving bodies, acclamations and
    /// transliterations byte-for-byte intact.</summary>
    private string _title = HebrewDisplayText.WithoutMarks(Title);
    private string? _subtitle = HebrewDisplayText.WithoutMarksOrNull(Subtitle);

    public string Title
    {
        get => _title;
        init => _title = HebrewDisplayText.WithoutMarks(value);
    }

    public string? Subtitle
    {
        get => _subtitle;
        init => _subtitle = HebrewDisplayText.WithoutMarksOrNull(value);
    }

    /// <summary>Alternate-artwork override the engine sets on Mystery-carrying steps when the
    /// favorite's <c>MysteryImageStyle</c> selects a non-default set (e.g.
    /// "eastern_joyful_01_annunciation"). A separate field rather than a rewrite of
    /// <see cref="Mystery"/>.<c>ImageKey</c> because that key is the mystery's identity and
    /// translation-lookup key.</summary>
    public string? ImageVariantKey { get; init; }
}
