package com.dkaluta.prosary.models

/** Where (if at all) "Eternal rest grant unto them, O Lord" is prayed for the faithful departed. */
enum class EternalRestPlacement {
    None,

    /** Pray it after the Glory Be of every decade. */
    AfterEachDecade,

    /** Pray it once, near the end, before the closing prayers. */
    AtEndOnly;

    val displayName: String
        get() = when (this) {
            None -> "Don't Include"
            AfterEachDecade -> "After Each Decade"
            AtEndOnly -> "Once, Near the End"
        }
}
