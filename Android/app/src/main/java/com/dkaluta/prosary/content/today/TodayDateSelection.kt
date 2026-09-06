package com.dkaluta.prosary.content.today

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Date

/** Material's picker stores UTC midnight; Today datasets use civil dates in the local zone. */
object TodayDateSelection {
    val earliest: LocalDate = LocalDate.of(1900, 1, 1)
    val latest: LocalDate = LocalDate.of(2100, 12, 31)
    fun pickerMillis(date: LocalDate): Long = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    fun fromPickerMillis(millis: Long): LocalDate = Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
    fun lookupDate(date: LocalDate, zone: ZoneId = ZoneId.systemDefault()): Date =
        Date.from(date.atTime(12, 0).atZone(zone).toInstant())
}
