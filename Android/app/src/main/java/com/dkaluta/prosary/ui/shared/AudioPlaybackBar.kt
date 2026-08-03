package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.audio.AudioPlaybackController

/**
 * The compact transport strip a prayer flow shows above its footer when the session's
 * devotion+language(+variant) has a narrated recording: chapter skip / play-pause controls,
 * the current chapter's title, and a seekable timeline. Pure presentation — all state lives in
 * [AudioPlaybackController], and chapter→step syncing is the owning flow screen's job.
 * Mirrors iOS's AudioPlaybackBar.
 */
@Composable
fun AudioPlaybackBar(
    controller: AudioPlaybackController,
    seasonColor: Color,
    /** The track's chapter titles, already resolved by the owning flow (titleKey goes through
     * the bundle content chain only the flow's context knows). */
    chapterTitles: List<String>,
    modifier: Modifier = Modifier,
) {
    val chapterCount = controller.track?.chapters?.size ?: 0

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
        ) {
            IconButton(onClick = { controller.previousChapter() }, enabled = chapterCount > 1) {
                Icon(Icons.Filled.SkipPrevious, contentDescription = stringResource(R.string.audio_previous_chapter))
            }
            IconButton(onClick = { controller.playPause() }) {
                Icon(
                    if (controller.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                    contentDescription = if (controller.isPlaying) stringResource(R.string.audio_pause) else stringResource(R.string.audio_play),
                    tint = seasonColor,
                    modifier = Modifier.size(34.dp),
                )
            }
            IconButton(onClick = { controller.nextChapter() }, enabled = chapterCount > 1) {
                Icon(Icons.Filled.SkipNext, contentDescription = stringResource(R.string.audio_next_chapter))
            }

            Column(modifier = Modifier.weight(1f)) {
                val chapterIndex = controller.currentChapterIndex
                if (chapterIndex != null && chapterIndex in chapterTitles.indices) {
                    Text(
                        chapterTitles[chapterIndex],
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // Scrubbing holds a local value and seeks once on release — seeking per
                    // drag-pixel storms the (asynchronous) MediaPlayer and fights the playback
                    // ticker's writes, snapping the thumb around mid-drag.
                    var scrubPosition by remember { mutableStateOf<Float?>(null) }
                    Slider(
                        value = scrubPosition ?: controller.currentTime.toFloat(),
                        onValueChange = { scrubPosition = it },
                        onValueChangeFinished = {
                            scrubPosition?.let { controller.seek(it.toDouble()) }
                            scrubPosition = null
                        },
                        valueRange = 0f..maxOf(controller.duration.toFloat(), 0.01f),
                        colors = SliderDefaults.colors(
                            thumbColor = seasonColor,
                            activeTrackColor = seasonColor,
                        ),
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        "${timestamp(controller.currentTime)}/${timestamp(controller.duration)}",
                        style = MaterialTheme.typography.labelSmall,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private fun timestamp(seconds: Double): String {
    val whole = seconds.toInt()
    return "%d:%02d".format(whole / 60, whole % 60)
}
