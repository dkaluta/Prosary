package com.dkaluta.prosary.models

import org.junit.Assert.*
import org.junit.Test

class PrayerCardTitleTest {
    @Test fun bilingualNamesRequireOptInAndDoNotRepeatIdenticalNames() {
        assertEquals(PrayerCardTitle("Our Father"), PrayerCardTitle.resolve("Our Father", "Pater Noster", false))
        assertEquals(PrayerCardTitle("Pater Noster", "Our Father"), PrayerCardTitle.resolve("Our Father", "Pater Noster", true))
        assertEquals(PrayerCardTitle("Our Father"), PrayerCardTitle.resolve("Our Father", "", true))
        assertEquals(PrayerCardTitle("שלום"), PrayerCardTitle.resolve("שלום", "שָׁלוֹם", true))
    }
}
