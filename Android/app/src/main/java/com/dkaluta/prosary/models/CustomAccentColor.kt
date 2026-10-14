package com.dkaluta.prosary.models

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import kotlin.math.max
import kotlin.math.min

/** Store the user's color exactly; derive readable action colors for each native surface. */
object CustomAccentColor {
    fun normalize(value: String?): String = value?.trim()?.removePrefix("#")
        ?.takeIf { Regex("[0-9a-fA-F]{6}").matches(it) }?.uppercase()?.let { "#$it" }.orEmpty()

    fun color(value: String): Color? = normalize(value).takeIf { it.isNotEmpty() }
        ?.drop(1)?.toLongOrNull(16)?.let { Color(0xFF000000L or it) }

    fun contrast(a: Color, b: Color): Float =
        (max(a.luminance(), b.luminance()) + .05f) / (min(a.luminance(), b.luminance()) + .05f)

    fun readableAccent(color: Color, dark: Boolean): Color {
        val surface = if (dark) Color(0xFF141218) else Color(0xFFFFFBFE)
        val destination = if (dark) Color.White else Color.Black
        var adjusted = color
        for (step in 0..100) {
            adjusted = lerp(color, destination, step / 100f)
            if (contrast(adjusted, surface) >= 4.5f) break
        }
        return adjusted
    }

    fun foreground(color: Color): Color =
        if (contrast(color, Color.White) >= contrast(color, Color.Black)) Color.White else Color.Black
}
