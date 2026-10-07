package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R

/** Holy See orientation: grips below, the teeth of both crossed keys facing outward. */
@Composable
internal fun PapalKeysIcon(modifier: Modifier = Modifier) {
    Icon(painterResource(R.drawable.ic_papal_keys), contentDescription = null,
        tint = MaterialTheme.colorScheme.primary, modifier = modifier.size(24.dp))
}
