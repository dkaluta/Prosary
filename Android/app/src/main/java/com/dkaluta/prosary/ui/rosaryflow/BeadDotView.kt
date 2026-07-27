package com.dkaluta.prosary.ui.rosaryflow

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dkaluta.prosary.ui.theme.BeadCompleted
import com.dkaluta.prosary.ui.theme.BeadUpcoming
import com.dkaluta.prosary.ui.theme.extraColors

@Composable
fun BeadDotView(bead: BeadInfo, modifier: Modifier = Modifier) {
    val color = when (bead.state) {
        BeadState.Current -> MaterialTheme.extraColors.beadCurrent
        BeadState.Completed -> BeadCompleted
        BeadState.Upcoming -> BeadUpcoming
    }
    val circleSize = if (bead.kind == BeadKind.Antiphon) 20.dp else 14.dp

    Box(modifier = modifier.size(20.dp), contentAlignment = Alignment.Center) {
        when (bead.kind) {
            BeadKind.Cross -> Canvas(modifier = Modifier.size(width = 13.dp, height = 17.dp)) {
                val armThickness = size.width * 0.34f
                val horizontalBarY = size.height * 0.22f
                drawRect(
                    color = color,
                    topLeft = Offset(size.width / 2f - armThickness / 2f, 0f),
                    size = Size(armThickness, size.height),
                )
                drawRect(
                    color = color,
                    topLeft = Offset(0f, horizontalBarY),
                    size = Size(size.width, armThickness),
                )
            }

            BeadKind.Decade -> Box(modifier = Modifier.size(circleSize).background(color, CircleShape))

            BeadKind.Antiphon -> Box(
                modifier = Modifier.size(circleSize).background(color, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("M", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 10.sp)
            }
        }
    }
}
