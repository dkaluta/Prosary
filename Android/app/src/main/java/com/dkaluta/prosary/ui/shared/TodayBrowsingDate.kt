package com.dkaluta.prosary.ui.shared

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.dkaluta.prosary.content.today.TodayDateSelection
import java.time.LocalDate

/** One window's browsing date, shared by Pray and Readings. Null keeps following today. */
@Stable
class TodayBrowsingDate(epochDay: Long? = null) {
    var selectedEpochDay by mutableStateOf(epochDay)

    fun selectedDate(today: LocalDate): LocalDate =
        (selectedEpochDay?.let(LocalDate::ofEpochDay) ?: today)
            .coerceIn(TodayDateSelection.earliest, TodayDateSelection.latest)
}

@Composable
fun rememberTodayBrowsingDate(): TodayBrowsingDate = rememberSaveable(
    saver = Saver(
        save = { it.selectedEpochDay ?: Long.MIN_VALUE },
        restore = { TodayBrowsingDate(it.takeUnless { value -> value == Long.MIN_VALUE }) },
    ),
) { TodayBrowsingDate() }
