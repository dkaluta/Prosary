package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Home cards have a separate order from the user's pinned prayer collection. */
enum class HomeWidget(val id: String) {
    Readings("readings"), PopeIntention("popeIntention"), Calendar("calendar"), Photo("photo"),
    Reminders("reminders"), Scripture("scripture"), Reflection("reflection"), Feast("feast");

    companion object {
        val defaults = listOf(Readings, PopeIntention, Calendar, Reminders, Scripture, Feast)

        /** An absent preference uses defaults; a saved empty string deliberately means no cards. */
        fun decode(stored: String?): List<HomeWidget> = if (stored == null) defaults else
            stored.split('\n').mapNotNull { id -> entries.firstOrNull { it.id == id } }.distinct()
    }
}

internal class HomeWidgetPreferences {
    companion object {
        const val orderKey = "homeWidgetOrder"
        const val photoKey = "homePhotoPath"
    }

    private var preferences: SharedPreferences? = null
    var widgets by mutableStateOf(HomeWidget.defaults)
        private set
    var photoPath by mutableStateOf("")
        private set

    fun initialize(storage: SharedPreferences) {
        preferences = storage
        widgets = HomeWidget.decode(storage.getString(orderKey, null))
        photoPath = storage.getString(photoKey, "").orEmpty()
    }

    fun updateWidgets(value: List<HomeWidget>) {
        widgets = value.distinct().toList()
        preferences?.edit()?.putString(orderKey, widgets.joinToString("\n") { it.id })?.apply()
    }

    fun add(widget: HomeWidget) = updateWidgets(widgets + widget)

    fun move(widget: HomeWidget, offset: Int) {
        val index = widgets.indexOf(widget)
        val destination = index + offset
        if (index < 0 || destination !in widgets.indices) return
        updateWidgets(widgets.toMutableList().apply { add(destination, removeAt(index)) })
    }

    fun updatePhotoPath(value: String) {
        photoPath = value
        preferences?.edit()?.putString(photoKey, value)?.apply()
    }
}
