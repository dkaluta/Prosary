package com.dkaluta.prosary.models

/** Discriminant for the type of a saved prayer session.
 * Add new cases here (and a matching options class) to expand into new devotions. */
enum class PrayerKind {
    Rosary,
    Angelus,
    JesusPrayer;

    val displayName: String
        get() = when (this) {
            Rosary -> "Rosary"
            Angelus -> "Angelus"
            JesusPrayer -> "Jesus Prayer"
        }

    /** Default name suggested when the user creates a new favorite of this kind. */
    val defaultName: String
        get() = when (this) {
            Rosary -> "My Rosary"
            Angelus -> "Angelus"
            JesusPrayer -> "Jesus Prayer"
        }
}
