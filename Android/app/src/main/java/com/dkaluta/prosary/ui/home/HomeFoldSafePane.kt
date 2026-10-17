package com.dkaluta.prosary.ui.home

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlin.math.roundToInt

/** The same Home subtree is remeasured as the real window's folding features change. */
@Composable
internal fun HomeFoldSafePane(content: @Composable () -> Unit) {
    val activity = LocalActivity.current
    val features = remember(activity) {
        if (activity == null) flowOf(emptyList())
        else WindowInfoTracker.getOrCreate(activity).windowLayoutInfo(activity).map { info ->
            info.displayFeatures.filterIsInstance<FoldingFeature>().map { feature ->
                HomeFoldBoundary(
                    HomePaneBounds(feature.bounds.left, feature.bounds.top, feature.bounds.right, feature.bounds.bottom),
                    horizontal = feature.orientation == FoldingFeature.Orientation.HORIZONTAL,
                    separating = feature.isSeparating,
                    occluding = feature.occlusionType == FoldingFeature.OcclusionType.FULL,
                )
            }
        }.catch { emit(emptyList()) }
    }
    val boundaries by features.collectAsStateWithLifecycle(initialValue = emptyList())
    var windowOrigin by remember { mutableStateOf(IntOffset.Zero) }
    Layout(content = { Box(Modifier.fillMaxSize().clipToBounds()) { content() } },
        modifier = Modifier.fillMaxSize().onGloballyPositioned { coordinates ->
        val origin = coordinates.positionInWindow()
        windowOrigin = IntOffset(origin.x.roundToInt(), origin.y.roundToInt())
    }) { measurables, constraints ->
        val viewport = HomePaneBounds(windowOrigin.x, windowOrigin.y,
            windowOrigin.x + constraints.maxWidth, windowOrigin.y + constraints.maxHeight)
        val pane = HomeFoldGeometry.safePane(viewport, boundaries)
        val child = measurables.single().measure(Constraints.fixed(pane.width, pane.height))
        layout(constraints.maxWidth, constraints.maxHeight) {
            // Absolute placement follows the physical hinge even in Hebrew/Arabic interfaces.
            child.place(pane.left - windowOrigin.x, pane.top - windowOrigin.y)
        }
    }
}
