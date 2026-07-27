package com.dkaluta.prosary.models

/** How many times the Jesus Prayer is prayed in a session. "Custom" is a setup-screen-only
 * concept (see JesusPrayerSetupScreen) — by the time a session starts it has already collapsed
 * into a plain [Count], so this type only ever distinguishes a fixed target from no target at
 * all. */
sealed interface JesusPrayerTarget {
    data class Count(val value: Int) : JesusPrayerTarget
    data object Unbounded : JesusPrayerTarget
}

/** Encodes a target into a nav-route path segment: the plain decimal count, or the literal word
 * "unbounded" — no tagged scheme needed, since "custom" isn't a distinct runtime value. */
fun JesusPrayerTarget.toRouteValue(): String = when (this) {
    is JesusPrayerTarget.Count -> value.toString()
    JesusPrayerTarget.Unbounded -> "unbounded"
}

/** Inverse of [toRouteValue]. Falls back to a 33-count target for a malformed value, though one
 * should never reach this point in practice. */
fun jesusPrayerTargetFromRouteValue(raw: String): JesusPrayerTarget =
    if (raw == "unbounded") JesusPrayerTarget.Unbounded else JesusPrayerTarget.Count(raw.toIntOrNull() ?: 33)
