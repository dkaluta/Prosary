package com.dkaluta.Prosary.engine

import com.dkaluta.Prosary.models.RosaryConfig
import com.dkaluta.Prosary.models.RosaryStep

/** What the UI needs from the backend to turn a saved preset into an actual, ordered prayer
 * session. This is the prayer-flow business logic boundary. */
interface RosaryEngine {
    /** Builds the full, ordered sequence of prayer steps for a Rosary session from a config. */
    fun buildSteps(config: RosaryConfig): List<RosaryStep>
}
