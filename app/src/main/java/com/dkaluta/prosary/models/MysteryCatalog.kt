package com.dkaluta.prosary.models

/** The fixed catalog of all twenty mysteries, grouped and ordered. This is static structural
 * data (which mystery is 3rd Sorrowful, etc.), not business logic — display text lives in the
 * content layer, keyed by each mystery's [Mystery.imageKey]. */
object MysteryCatalog {
    val joyful: List<Mystery> = listOf(
        Mystery(group = MysteryGroup.Joyful, order = 1, imageKey = "joyful_01_annunciation"),
        Mystery(group = MysteryGroup.Joyful, order = 2, imageKey = "joyful_02_visitation"),
        Mystery(group = MysteryGroup.Joyful, order = 3, imageKey = "joyful_03_nativity"),
        Mystery(group = MysteryGroup.Joyful, order = 4, imageKey = "joyful_04_presentation"),
        Mystery(group = MysteryGroup.Joyful, order = 5, imageKey = "joyful_05_finding_in_the_temple"),
    )

    val sorrowful: List<Mystery> = listOf(
        Mystery(group = MysteryGroup.Sorrowful, order = 1, imageKey = "sorrowful_01_agony_in_the_garden"),
        Mystery(group = MysteryGroup.Sorrowful, order = 2, imageKey = "sorrowful_02_scourging_at_the_pillar"),
        Mystery(group = MysteryGroup.Sorrowful, order = 3, imageKey = "sorrowful_03_crowning_with_thorns"),
        Mystery(group = MysteryGroup.Sorrowful, order = 4, imageKey = "sorrowful_04_carrying_of_the_cross"),
        Mystery(group = MysteryGroup.Sorrowful, order = 5, imageKey = "sorrowful_05_crucifixion"),
    )

    val glorious: List<Mystery> = listOf(
        Mystery(group = MysteryGroup.Glorious, order = 1, imageKey = "glorious_01_resurrection"),
        Mystery(group = MysteryGroup.Glorious, order = 2, imageKey = "glorious_02_ascension"),
        Mystery(group = MysteryGroup.Glorious, order = 3, imageKey = "glorious_03_descent_of_the_holy_spirit"),
        Mystery(group = MysteryGroup.Glorious, order = 4, imageKey = "glorious_04_assumption"),
        Mystery(group = MysteryGroup.Glorious, order = 5, imageKey = "glorious_05_coronation"),
    )

    val luminous: List<Mystery> = listOf(
        Mystery(group = MysteryGroup.Luminous, order = 1, imageKey = "luminous_01_baptism"),
        Mystery(group = MysteryGroup.Luminous, order = 2, imageKey = "luminous_02_wedding_at_cana"),
        Mystery(group = MysteryGroup.Luminous, order = 3, imageKey = "luminous_03_proclamation_of_the_kingdom"),
        Mystery(group = MysteryGroup.Luminous, order = 4, imageKey = "luminous_04_transfiguration"),
        Mystery(group = MysteryGroup.Luminous, order = 5, imageKey = "luminous_05_institution_of_the_eucharist"),
    )

    fun forGroup(group: MysteryGroup): List<Mystery> = when (group) {
        MysteryGroup.Joyful -> joyful
        MysteryGroup.Sorrowful -> sorrowful
        MysteryGroup.Glorious -> glorious
        MysteryGroup.Luminous -> luminous
    }

    val all: List<Mystery> get() = joyful + sorrowful + glorious + luminous
}
