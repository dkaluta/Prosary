package com.dkaluta.Prosary.engine

import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.RosaryStep

/** What the UI needs from the backend to turn a saved favorite into an actual, ordered prayer
 * session. This is the prayer-flow business logic boundary. */
interface RosaryEngine {
    /** Builds the full, ordered sequence of prayer steps for a Rosary session. */
    fun buildSteps(prayer: Prayer): List<RosaryStep>
}
