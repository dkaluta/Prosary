package com.dkaluta.prosary.models

import java.util.UUID

/** What the UI needs from the backend to render one prayer "bead" in a fully built Rosary
 * session. The backend (PrayerEngine) is responsible for producing an ordered list of these
 * from a Prayer; the UI only ever reads them. */
data class RosaryStep(
    val id: String = UUID.randomUUID().toString(),
    /** The prominent heading, e.g. "Hail Mary (3 of 10)" or "Our Father". */
    val title: String,
    /** Muted decade context shown above the title, e.g. "1st Mystery — The Annunciation". Null for steps not tied to a decade. */
    val subtitle: String? = null,
    /** The full prayer text to display/read. */
    val body: String,
    /** Optional acclamation (the Stations' versicle/response) rendered above the body in the
     * regular prayer typeface — kept out of [body] so a scripture body's typeface doesn't
     * swallow the acclamation, which is a prayer, not part of the reading. */
    val acclamation: String? = null,
    /** The mystery illustrated on screen for this step, if any. */
    val mystery: Mystery? = null,
    /** True only for the mystery-announcement step, whose body is an actual quoted Bible verse rather than a traditional prayer. */
    var isScripture: Boolean = false,
    /** True only for the Marian antiphon step (the "M" bead in the progress indicator). */
    var isAntiphon: Boolean = false,
    /** 0-based index of this step's decade, counted globally across every mystery group in the session (0..<N for an N-decade session). Null for steps not tied to a decade (opening, antiphon, closing, etc). */
    val decadeIndex: Int? = null,
    /** 1-10 for the ten Hail Mary steps within a decade; null otherwise. */
    val hailMaryIndexInDecade: Int? = null,
    /** Image key for steps not tied to a Mystery but that still want a specific illustration (e.g. "crucifix" for the Sign of the Cross/Apostles' Creed, "madonna_and_child" for the antiphon) instead of the generic placeholder. */
    var imageOverrideKey: String? = null,
) {
    /** The drawable resource name this step should display: the mystery's own image, an
     * explicit override, or the neutral placeholder. */
    val imageKey: String
        get() = mystery?.imageKey ?: imageOverrideKey ?: "cross_placeholder"
}
