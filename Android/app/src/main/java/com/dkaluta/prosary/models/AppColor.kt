package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import com.dkaluta.prosary.R

/** Shared appColor identifiers; white uses a gold accent so controls remain legible. */
enum class AppColor(
    val id: String,
    @get:StringRes val labelRes: Int,
    val light: Long,
    val dark: Long,
) {
    Blue("blue", R.string.app_color_blue, 0xFF1768AC, 0xFF8DC8FF),
    Green("green", R.string.app_color_green, 0xFF287D49, 0xFF8AD4A1),
    Red("red", R.string.app_color_red, 0xFFB52E3E, 0xFFFFB1B5),
    Purple("purple", R.string.app_color_purple, 0xFF7545A0, 0xFFD7B4F4),
    Rose("rose", R.string.app_color_rose, 0xFFAD3F70, 0xFFF3B0CB),
    White("white", R.string.app_color_white, 0xFF8B681B, 0xFFF0D389),
    Gold("gold", R.string.app_color_gold, 0xFF886419, 0xFFF0D389);

    val launcherClass: String get() = "com.dkaluta.prosary.launcher.$name"

    companion object {
        fun resolve(id: String?): AppColor = entries.firstOrNull { it.id == id } ?: Blue
    }
}
