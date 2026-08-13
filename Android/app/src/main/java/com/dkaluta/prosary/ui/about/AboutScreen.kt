package com.dkaluta.prosary.ui.about

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.ui.theme.extraColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(onBack: () -> Unit) {
    // Tints the pinned bar once content scrolls beneath it — without this the bar is
    // invisible and scrolled content clips at a dead band around the floating title.
    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()
    Scaffold(
        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text(stringResource(R.string.about_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .widthIn(max = 560.dp)
                .fillMaxWidth()
                .padding(24.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "Prosary",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.extraColors.headline,
                )
                Text(
                    stringResource(R.string.about_tagline),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_typefaces)) {
                BoldLeadLine("Frank Ruhl Libre", stringResource(R.string.about_typeface_frank_ruhl))
                BoldLeadLine("Shofar", stringResource(R.string.about_typeface_shofar))
                BoldLeadLine("Amiri", stringResource(R.string.about_typeface_amiri))
                BoldLeadLine("Scheherazade New", stringResource(R.string.about_typeface_scheherazade))
                BoldLeadLine("Cardo", stringResource(R.string.about_typeface_cardo))
                Text(
                    stringResource(R.string.about_typefaces_footer),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }

            AboutSection(title = stringResource(R.string.about_mystery_illustrations)) {
                Text(
                    stringResource(R.string.about_mystery_intro),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                stringArrayResource(R.array.about_mystery_attributions).forEach { line -> ItalicLeadLine(line) }
                Text(
                    stringResource(R.string.about_eastern_icons),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_other_images)) {
                stringArrayResource(R.array.about_other_image_attributions).forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = stringResource(R.string.about_stations_illustrations)) {
                Text(
                    stringResource(R.string.about_stations_fugel),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    stringResource(R.string.about_stations_scriptural),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    stringResource(R.string.about_stations_via_lucis),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_crown_illustration)) {
                Text(
                    stringResource(R.string.about_crown_magi),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_sorrows_illustrations)) {
                stringArrayResource(R.array.about_sorrows_attributions).forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = stringResource(R.string.about_mercy_illustration)) {
                Text(
                    stringResource(R.string.about_mercy_kazimirowski),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_jesus_prayer_illustration)) {
                Text(
                    stringResource(R.string.about_jesus_pantocrator),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_prayer_texts)) {
                Text(
                    stringResource(R.string.about_prayer_texts_body),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = stringResource(R.string.about_scripture_sources)) {
                Text(
                    stringResource(R.string.about_scripture_text),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun AboutSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.extraColors.headline,
        )
        content()
    }
}

@Composable
private fun BoldLeadLine(bold: String, rest: String) {
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(bold) }
            append(rest)
        },
    )
}

/** Renders lines of the form `*Italicized Title* — rest of the line`. */
@Composable
private fun ItalicLeadLine(line: String) {
    val firstStar = line.indexOf('*')
    val secondStar = if (firstStar >= 0) line.indexOf('*', firstStar + 1) else -1

    val annotated = if (firstStar == 0 && secondStar > firstStar) {
        buildAnnotatedString {
            withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(line.substring(firstStar + 1, secondStar)) }
            append(line.substring(secondStar + 1))
        }
    } else {
        buildAnnotatedString { append(line) }
    }

    Text(annotated)
}



