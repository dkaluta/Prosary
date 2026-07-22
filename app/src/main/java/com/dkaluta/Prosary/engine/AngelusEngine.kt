package com.dkaluta.Prosary.engine

import com.dkaluta.Prosary.models.RosaryStep

/** What the UI needs from the backend to build the Angelus. Unlike the Rosary, the Angelus isn't
 * user-configurable — there's no config to pass, just a language — so this is the prayer-flow
 * business logic boundary for a fixed devotion. */
interface AngelusEngine {
    /** Builds the full, ordered sequence of prayer steps for an Angelus session in the given
     * language — the standard three-versicle form, or the Regina Caeli substitute during
     * Eastertide. */
    fun buildSteps(languageCode: String?): List<RosaryStep>
}
