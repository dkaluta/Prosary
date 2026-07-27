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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.ui.theme.extraColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("About Prosary") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
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
                    "A companion for praying the Rosary and other Catholic devotions.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = "Typefaces") {
                BoldLeadLine("Frank Ruhl Libre", " — SIL Open Font License 1.1 — Hebrew prayers.")
                BoldLeadLine("Shofar", " — GPL v2 with font-embedding exception — Hebrew Scripture (Culmus Project, Yoram Gnat).")
                BoldLeadLine("Amiri", " — SIL Open Font License 1.1 — Arabic prayers.")
                BoldLeadLine("Scheherazade New", " — SIL Open Font License 1.1 — Arabic Scripture (SIL).")
                BoldLeadLine("Cardo", " — SIL Open Font License 1.1 — Latin/English Scripture (David J. Perry).")
                Text(
                    "Latin-script prayers use the platform's system serif design — not bundled with the app.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }

            AboutSection(title = "Mystery Illustrations") {
                Text(
                    "All 20 mystery images are classical paintings in the public domain (artist deceased over 100 years), sourced from Wikimedia Commons.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                mysteryAttributions.forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = "Other Images") {
                otherImageAttributions.forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = "Stations of the Cross Illustrations") {
                Text(
                    "Placeholder illustrations for now — real public-domain artwork with proper " +
                        "attribution hasn't been sourced yet for the 14 stations.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                stationAttributions.forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = "Franciscan Crown Illustration") {
                Text(
                    "Six of the Seven Joys reuse the Rosary mystery images above (Annunciation, Visitation, " +
                        "Nativity, Finding in the Temple, Resurrection, Coronation). Only the Adoration of the " +
                        "Magi is new, and its illustration is a placeholder for now — real public-domain " +
                        "artwork with proper attribution hasn't been sourced yet.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                ItalicLeadLine("*The Adoration of the Magi* — artwork pending.")
            }

            AboutSection(title = "Seven Sorrows Illustrations") {
                Text(
                    "Placeholder illustrations for now — real public-domain artwork with proper " +
                        "attribution hasn't been sourced yet for any of the 7 sorrows.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                sevenSorrowsAttributions.forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = "Divine Mercy Illustration") {
                Text(
                    "The single Divine Mercy illustration, reused for every step (the chaplet has no " +
                        "per-decade content to illustrate separately), is a placeholder for now — real " +
                        "public-domain artwork with proper attribution hasn't been sourced yet.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                ItalicLeadLine("*Divine Mercy* — artwork pending.")
            }

            AboutSection(title = "Scripture Sources") {
                Text(
                    "Mystery meditations quote the Douay-Rheims Bible (English), the Clementine Vulgate (Latin), " +
                        "Franz Delitzsch's Hebrew New Testament translation (sourced from kirjasilta.net/ha-berit), " +
                        "the Jesuit Arabic Bible (Beirut, 1880, revised 1988), the Russian Synodal Bible (1876), and " +
                        "Ang Dating Biblia (Tagalog, 1905) — all public domain.",
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

private val mysteryAttributions = listOf(
    "*The Annunciation* — Fra Angelico (d. 1455)",
    "*The Visitation* — Mariotto Albertinelli (d. 1515)",
    "*The Holy Night* — Antonio da Correggio (d. 1534)",
    "*The Presentation at the Temple* — Andrea Mantegna (d. 1506)",
    "*Christ Discovered in the Temple* — Simone Martini (d. 1344)",
    "*The Baptism of Christ* — Piero della Francesca (d. 1492)",
    "*The Wedding at Cana* — Paolo Veronese (d. 1588)",
    "*The Sermon on the Mount* — Cosimo Rosselli (d. 1507)",
    "*The Transfiguration* — Raphael (d. 1520)",
    "*The Last Supper* — Leonardo da Vinci (d. 1519)",
    "*The Agony in the Garden* — Andrea Mantegna (d. 1506)",
    "*The Flagellation of Christ* — Caravaggio (d. 1610)",
    "*The Crowning with Thorns* — Caravaggio (d. 1610)",
    "*Christ Carrying the Cross* — Titian (d. 1576)",
    "*Christ Crucified* — Diego Velázquez (d. 1660)",
    "*The Resurrection* — Piero della Francesca (d. 1492)",
    "*The Ascension of Christ* — Rembrandt (d. 1669)",
    "*The Pentecost* — El Greco (d. 1614)",
    "*Assumption of the Virgin* — Titian (d. 1576)",
    "*Coronation of the Virgin* — Diego Velázquez (d. 1660)",
)

private val otherImageAttributions = listOf(
    "*Crucifix* — Cimabue (d. 1302).",
    "*The Small Cowper Madonna* — Raphael (d. 1520).",
    "*Faith, Hope, and Charity* — Raphael, Baglioni altarpiece predella (d. 1520).",
    "*Praying Hands* — Albrecht Dürer (d. 1528).",
    "*Holy Trinity* — Masaccio (d. 1428).",
    "*Christ in Limbo* — Fra Angelico (d. 1455).",
    "*Michael* — Guido Reni (d. 1642).",
    "*Head of Christ* — Rembrandt (d. 1669).",
)

/** Placeholder illustrations for now (see the intro line above) — real public-domain artwork
 * with proper attribution hasn't been sourced yet for the 14 stations. */
private val stationAttributions = listOf(
    "*Station 1: Jesus is Condemned to Death* — artwork pending.",
    "*Station 2: Jesus Carries His Cross* — artwork pending.",
    "*Station 3: Jesus Falls the First Time* — artwork pending.",
    "*Station 4: Jesus Meets His Mother* — artwork pending.",
    "*Station 5: Simon of Cyrene Helps Jesus Carry the Cross* — artwork pending.",
    "*Station 6: Veronica Wipes the Face of Jesus* — artwork pending.",
    "*Station 7: Jesus Falls the Second Time* — artwork pending.",
    "*Station 8: Jesus Meets the Women of Jerusalem* — artwork pending.",
    "*Station 9: Jesus Falls the Third Time* — artwork pending.",
    "*Station 10: Jesus is Stripped of His Garments* — artwork pending.",
    "*Station 11: Jesus is Nailed to the Cross* — artwork pending.",
    "*Station 12: Jesus Dies on the Cross* — artwork pending.",
    "*Station 13: Jesus is Taken Down from the Cross* — artwork pending.",
    "*Station 14: Jesus is Laid in the Tomb* — artwork pending.",
)

/** Placeholder illustrations for now (see the intro line above) — real public-domain artwork
 * with proper attribution hasn't been sourced yet for any of the 7 sorrows. */
private val sevenSorrowsAttributions = listOf(
    "*Sorrow 1: The Prophecy of Simeon* — artwork pending.",
    "*Sorrow 2: The Flight into Egypt* — artwork pending.",
    "*Sorrow 3: The Loss of the Child Jesus in the Temple* — artwork pending.",
    "*Sorrow 4: Mary Meets Jesus on the Way of the Cross* — artwork pending.",
    "*Sorrow 5: Mary at the Foot of the Cross* — artwork pending.",
    "*Sorrow 6: Mary Receives the Body of Jesus* — artwork pending.",
    "*Sorrow 7: The Burial of Jesus* — artwork pending.",
)
