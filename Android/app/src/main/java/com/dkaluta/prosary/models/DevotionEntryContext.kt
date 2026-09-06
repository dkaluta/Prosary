package com.dkaluta.prosary.models

/** Loreto's collect follows how this session began, never a saved favorite's form. */
object DevotionEntryContext {
    fun locksVariant(devotionId: String): Boolean = devotionId == "litanyOfLoreto"

    fun initialVariant(devotionId: String, handoffVariant: String?, savedVariant: String?): String? =
        if (locksVariant(devotionId)) {
            if (handoffVariant == "afterRosary") "afterRosary" else "standard"
        } else {
            handoffVariant ?: savedVariant
        }
}
