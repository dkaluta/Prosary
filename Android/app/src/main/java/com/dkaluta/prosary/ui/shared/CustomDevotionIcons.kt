package com.dkaluta.prosary.ui.shared

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.ChangeHistory
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/** Maps a bundle manifest's `iconSystemName` (an SF Symbol name, the iOS convention — see
 * Shared/ARCHITECTURE.md's "Content bundles" section) to the nearest Material icon. Small and
 * fixed by design: a generic devotion's icon choice is authored once in its manifest.json, so
 * this only needs an entry per icon name actually in use, not a general SF-Symbol-to-Material
 * translator. */
fun iconForSystemName(systemName: String?): ImageVector = when (systemName) {
    "bell" -> Icons.Filled.Notifications
    "figure.walk" -> Icons.AutoMirrored.Filled.DirectionsWalk
    "crown" -> Icons.Filled.WorkspacePremium
    "drop" -> Icons.Filled.WaterDrop
    "sun.max" -> Icons.Filled.WbSunny
    "triangle" -> Icons.Filled.ChangeHistory
    else -> Icons.Filled.Star
}

/** Parses a bundle manifest's `accentColorHex` (e.g. "#00796B") into a Compose [Color], or null
 * if absent/unparseable — callers fall back to a default accent in that case. */
fun colorForHex(hex: String?): Color? {
    if (hex == null) return null
    return runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrNull()
}
