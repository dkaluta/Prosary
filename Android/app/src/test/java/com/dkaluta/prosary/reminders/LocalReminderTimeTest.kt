package com.dkaluta.prosary.reminders

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.ZonedDateTime
import java.time.ZoneId
import java.util.TimeZone

class LocalReminderTimeTest {
    @Test fun springAndAutumnKeepTheChosenLocalHour() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            for ((before, hours) in listOf("2026-03-07T10:00:00-05:00[America/New_York]" to 23,
                "2026-10-31T10:00:00-04:00[America/New_York]" to 25)) {
                val now = ZonedDateTime.parse(before)
                val next = ReminderScheduler.nextTriggerTimeMillis(9, 0, now.toInstant().toEpochMilli())
                val local = java.time.Instant.ofEpochMilli(next).atZone(ZoneId.of("America/New_York"))
                assertEquals(9, local.hour)
                assertEquals(0, local.minute)
                assertEquals(hours.toLong(), java.time.Duration.between(now.plusHours(-1).toInstant(), local.toInstant()).toHours())
            }
        } finally { TimeZone.setDefault(original) }
    }

    @Test fun changingZonesChangesTheInstantButKeepsTheCivilTime() {
        val original = TimeZone.getDefault()
        try {
            val now = java.time.Instant.parse("2026-10-02T00:00:00Z").toEpochMilli()
            for (zone in listOf("Asia/Jerusalem", "Europe/Paris")) {
                TimeZone.setDefault(TimeZone.getTimeZone(zone))
                val next = ReminderScheduler.nextTriggerTimeMillis(9, 30, now)
                val local = java.time.Instant.ofEpochMilli(next).atZone(ZoneId.of(zone))
                assertEquals(9, local.hour)
                assertEquals(30, local.minute)
            }
        } finally { TimeZone.setDefault(original) }
    }
}
