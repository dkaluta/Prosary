package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Home cards have a separate order from the user's pinned prayer collection. */
enum class HomeWidget(val id: String) {
    Readings("readings"), Torah("torah"), PopeIntention("popeIntention"), Calendar("calendar"), Photo("photo"),
    Reminders("reminders"), Scripture("scripture"), Reflection("reflection"), Feast("feast");

    companion object {
        val defaults = listOf(Readings, Torah, PopeIntention, Calendar, Reminders, Scripture, Feast, Reflection)

        /** An absent preference uses defaults; a saved empty string deliberately means no cards. */
        fun decode(stored: String?): List<HomeWidget> = if (stored == null) defaults else
            stored.split('\n').mapNotNull { id -> entries.firstOrNull { it.id == id } }.distinct()

        fun addingDailyCards(widgets: List<HomeWidget>): List<HomeWidget> =
            if (widgets.isEmpty()) widgets else widgets.toMutableList().apply {
                if (Torah !in this) add(indexOf(Readings).takeIf { it >= 0 }?.plus(1) ?: 0, Torah)
                if (Reflection !in this) add(Reflection)
            }
    }
}

internal class HomeWidgetPreferences {
    companion object {
        const val orderKey = "homeWidgetOrder"
        const val photoKey = "homePhotoPath"
        const val collapsedKey = "homeWidgetCollapsedIds"
        const val graphicsKey = "homeWidgetGraphicPaths"
        const val layoutVersionKey = "homeWidgetLayoutVersion"
        const val colorsKey = "homeWidgetColors"
        val colorIds = listOf("default", "blue", "green", "gold", "rose")

        fun parseColors(stored: String?): Map<String, String> = runCatching {
            Json.decodeFromString<Map<String, String>>(stored ?: "{}")
        }.getOrDefault(emptyMap()).filter { (id, color) ->
            HomeWidget.entries.any { it.id == id } && color != "default" && color in colorIds
        }
    }

    private var preferences: SharedPreferences? = null
    var widgets by mutableStateOf(HomeWidget.defaults)
        private set
    var photoPath by mutableStateOf("")
        private set
    var collapsed by mutableStateOf(emptySet<HomeWidget>())
        private set
    var graphicPaths by mutableStateOf(emptyMap<String, String>())
        private set
    var colors by mutableStateOf(emptyMap<String, String>())
        private set

    fun initialize(storage: SharedPreferences) {
        preferences = storage
        widgets = HomeWidget.decode(storage.getString(orderKey, null))
        if (storage.getString(layoutVersionKey, null) != "1") {
            widgets = HomeWidget.addingDailyCards(widgets)
            storage.edit().putString(orderKey, widgets.joinToString("\n") { it.id })
                .putString(layoutVersionKey, "1").apply()
        }
        photoPath = storage.getString(photoKey, "").orEmpty()
        collapsed = storage.getString(collapsedKey, "").orEmpty().split('\n')
            .mapNotNull { id -> HomeWidget.entries.firstOrNull { it.id == id } }.toSet()
        graphicPaths = runCatching { Json.decodeFromString<Map<String, String>>(storage.getString(graphicsKey, "{}").orEmpty()) }
            .getOrDefault(emptyMap()).filter { (id, path) -> HomeWidget.entries.any { it.id == id } && path.isNotBlank() }
        colors = parseColors(storage.getString(colorsKey, "{}"))
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

    fun setCollapsed(widget: HomeWidget, value: Boolean) {
        collapsed = if (value) collapsed + widget else collapsed - widget
        preferences?.edit()?.putString(collapsedKey, HomeWidget.entries.filter { it in collapsed }.joinToString("\n") { it.id })?.apply()
    }

    fun setGraphicPath(widget: HomeWidget, path: String) {
        graphicPaths = if (path.isBlank()) graphicPaths - widget.id else graphicPaths + (widget.id to path)
        preferences?.edit()?.putString(graphicsKey, Json.encodeToString(graphicPaths))?.apply()
    }

    fun setColor(widget: HomeWidget, color: String) {
        colors = if (color == "default" || color !in colorIds) colors - widget.id else colors + (widget.id to color)
        preferences?.edit()?.putString(colorsKey, Json.encodeToString<Map<String, String>>(colors.toSortedMap()))?.apply()
    }
}
