package com.dkaluta.prosary.models

/** Standalone Loreto always has its own collect; embedded Rosary expansion is engine-owned. */
object DevotionEntryContext {
    fun locksVariant(devotionId: String): Boolean = devotionId == "litanyOfLoreto"

    fun initialVariant(devotionId: String, handoffVariant: String?, savedVariant: String?): String? =
        if (locksVariant(devotionId)) {
            "standard"
        } else {
            handoffVariant ?: savedVariant
        }
}
