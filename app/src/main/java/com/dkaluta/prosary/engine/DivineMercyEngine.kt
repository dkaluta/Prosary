package com.dkaluta.prosary.engine

import com.dkaluta.prosary.models.RosaryStep

/** What the UI needs from the backend to build the Divine Mercy Chaplet. Like the Franciscan
 * Crown/Seven Sorrows, it isn't user-configurable — there's no config to pass, just a language —
 * it's always the same fixed sequence: opening prayers, 5 decades of an offering + 10 petitions
 * (the same two lines repeated every decade, unlike the Rosary/Franciscan Crown/Seven Sorrows,
 * none of which repeat identical content across decades), closing with the acclamation prayed
 * three times. */
interface DivineMercyEngine {
    /** Builds the full, ordered sequence of prayer steps for a Divine Mercy Chaplet session in
     * the given language. */
    fun buildSteps(languageCode: String?): List<RosaryStep>
}
