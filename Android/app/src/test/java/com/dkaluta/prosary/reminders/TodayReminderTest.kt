package com.dkaluta.prosary.reminders

import com.dkaluta.prosary.content.today.FeastDay
import com.dkaluta.prosary.content.today.FeastObservance
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TodayReminderTest {
    @Test fun saintNotificationsKeepSourceCreditAndNeverBorrowAnotherLanguage() {
        val feast = FeastDay("Fixture feast", "Feast", observances = listOf(FeastObservance(
            "Fixture saint", "fixture", descriptionByLanguage = mapOf("he" to "Source paragraph."),
            descriptionCreditByLanguage = mapOf("he" to "Source credit."))))
        val sourced = TodayReminderScheduler.saintBody(feast, "syriac", "he")
        assertTrue(sourced.contains("Source paragraph."))
        assertTrue(sourced.contains("Source credit."))
        for ((calendar, language) in listOf("roman" to "en", "syriac" to "en")) {
            val fallback = TodayReminderScheduler.saintBody(feast, calendar, language)
            assertTrue(fallback.contains("Fixture feast"))
            assertFalse(fallback.contains("Source paragraph."))
        }
    }
}
