package com.dkaluta.prosary.ui.settings

import android.os.Build
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap
import com.dkaluta.prosary.LauncherIconController
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppearanceScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()
    Scaffold(
        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection).testTag("appearanceScreen"),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_appearance)) },
                scrollBehavior = topBarScroll,
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                    }
                },
            )
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.TopCenter) {
            Column(
                modifier = Modifier.widthIn(max = 640.dp).fillMaxWidth()
                    .verticalScroll(rememberScrollState()).testTag("appearanceList").padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                Text(stringResource(R.string.settings_app_color_hint),
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Surface(shape = MaterialTheme.shapes.extraLarge, color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Column(Modifier.selectableGroup()) {
                        AppColor.entries.forEachIndexed { index, color ->
                            val selected = AppSettings.appColor == color.id
                            ListItem(
                                headlineContent = { Text(stringResource(color.labelRes)) },
                                leadingContent = { AppColorIcon(color) },
                                trailingContent = { RadioButton(selected = selected, onClick = null) },
                                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                                modifier = Modifier.fillMaxWidth().heightIn(min = 96.dp)
                                    .selectable(selected = selected, role = Role.RadioButton, onClick = {
                                        if (!LauncherIconController.select(context, color.id)) {
                                            Toast.makeText(context, R.string.settings_app_color_error, Toast.LENGTH_LONG).show()
                                        }
                                    }).testTag("appColor.${color.id}"),
                            )
                            if (index < AppColor.entries.lastIndex) {
                                HorizontalDivider(Modifier.padding(start = 96.dp, end = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
                            }
                        }
                    }
                }
                if (Build.VERSION.SDK_INT >= 31) {
                    Surface(shape = MaterialTheme.shapes.extraLarge, color = MaterialTheme.colorScheme.surfaceContainerLow) {
                        ListItem(
                            headlineContent = { Text(stringResource(R.string.settings_use_system_colors)) },
                            supportingContent = { Text(stringResource(R.string.settings_use_system_colors_hint)) },
                            trailingContent = { Switch(checked = AppSettings.useSystemColors, onCheckedChange = null) },
                            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                            modifier = Modifier.fillMaxWidth().toggleable(
                                value = AppSettings.useSystemColors, role = Role.Switch,
                                onValueChange = { AppSettings.useSystemColors = it },
                            ).testTag("useSystemColors"),
                        )
                    }
                }
            }
        }
    }
}

/** Draw the actual launcher resource, including adaptive masks and the white icon's gold cross.
 * The preview remains full color even when the device uses themed launcher icons. */
@Composable
private fun AppColorIcon(color: AppColor) {
    val context = LocalContext.current
    val size = with(LocalDensity.current) { 64.dp.roundToPx() }
    val bitmap = remember(context, color, size) {
        requireNotNull(context.getDrawable(color.iconRes)).toBitmap(width = size, height = size).asImageBitmap()
    }
    Image(bitmap = bitmap, contentDescription = null, modifier = Modifier.size(64.dp).testTag("appColorIcon.${color.id}"))
}
