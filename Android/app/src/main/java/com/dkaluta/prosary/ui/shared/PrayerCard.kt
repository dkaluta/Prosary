package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.typography.HebrewDisplayText

/** Tappable devotion card on the Pray tab. Accent strip color is passed in by the
 * caller so the Rosary card can use the dynamic mystery-group color of the day. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PrayerCard(
    icon: ImageVector,
    iconGlyph: String? = null,
    title: String,
    subtitle: String,
    accentColor: Color,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    interfaceTitle: String? = null,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
    ) {
        Box(modifier = Modifier.width(5.dp).fillMaxHeight().background(accentColor))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            if (iconGlyph != null) {
                // Compose's "your own" one-grapheme icon (v0.7, Gamaliel item 6).
                Text(
                    iconGlyph,
                    color = accentColor,
                    style = MaterialTheme.typography.headlineSmall,
                    modifier = Modifier.width(28.dp),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            } else {
                Icon(icon, contentDescription = null, tint = accentColor, modifier = Modifier.size(28.dp))
            }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(HebrewDisplayText.unpoint(title), style = MaterialTheme.typography.titleMedium)
                if (!interfaceTitle.isNullOrBlank()) {
                    Text(HebrewDisplayText.unpoint(interfaceTitle), style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (subtitle.isNotEmpty() && subtitle != title && subtitle != interfaceTitle) {
                    Text(
                        HebrewDisplayText.unpoint(subtitle),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.outline,
            )
        }
    }
}
