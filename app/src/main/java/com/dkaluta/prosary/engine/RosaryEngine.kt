package com.dkaluta.prosary.engine

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryStep

/** What the UI needs from the backend to turn a saved favorite into an actual, ordered prayer
 * session. This is the prayer-flow business logic boundary. */
interface RosaryEngine {
    /** Builds the full, ordered sequence of prayer steps for a Rosary session. */
    fun buildSteps(prayer: Prayer): List<RosaryStep>
}
