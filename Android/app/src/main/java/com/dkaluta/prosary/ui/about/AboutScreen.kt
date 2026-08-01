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
                    "All 14 stations: Gebhard Fugel (1863\u20131939), Kreuzweg (1921), St. Antonius, " +
                        "Bad Saulgau \u2014 public domain; photographs by Andreas Praefcke, released into " +
                        "the public domain.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "The scriptural (St. John Paul II) form adds: The Kiss of Judas \u2014 Giotto " +
                        "(Scrovegni Chapel, c. 1305); Christ before the High Priest \u2014 Gerrit van " +
                        "Honthorst (c. 1617), National Gallery, London; The Denial of St Peter \u2014 " +
                        "Rembrandt (1660), Rijksmuseum; Le Coup de Lance \u2014 Peter Paul Rubens (1620), " +
                        "Royal Museum of Fine Arts Antwerp \u2014 all public domain. Its other scenes " +
                        "reuse illustrations listed elsewhere on this page.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    "The Via Lucis scenes: The Disciples at the Tomb \u2014 Eug\u00e8ne Burnand (1898), " +
                        "Mus\u00e9e d'Orsay; Noli me tangere \u2014 Fra Angelico (San Marco, c. 1440); " +
                        "The Road to Emmaus, the appearances to the apostles, at Lake Tiberias, and in " +
                        "Galilee \u2014 Duccio di Buoninsegna (Maest\u00e0, 1308\u20131311), Siena; " +
                        "Supper at Emmaus (1601) and The Incredulity of Saint Thomas (1601\u20131602) \u2014 " +
                        "Caravaggio; Christ's Charge to Peter \u2014 Raphael (c. 1515), Royal Collection; " +
                        "The Virgin in Prayer \u2014 Sassoferrato (1640\u20131650), National Gallery, " +
                        "London \u2014 all public domain. Its other scenes reuse the Rosary's " +
                        "glorious-mystery illustrations.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = "Franciscan Crown Illustration") {
                Text(
                    "The Adoration of the Magi: Bartolom\u00E9 Esteban Murillo (c. 1655\u201360), " +
                        "Toledo Museum of Art \u2014 public domain. The other six Joys reuse the Rosary " +
                        "mystery illustrations above.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = "Seven Sorrows Illustrations") {
                sevenSorrowsAttributions.forEach { line -> ItalicLeadLine(line) }
            }

            AboutSection(title = "Divine Mercy Illustration") {
                Text(
                    "Eugeniusz Kazimirowski, Divine Mercy (\u201CJezu, ufam Tobie\u201D, 1934), Divine " +
                        "Mercy Sanctuary, Vilnius \u2014 the original image painted under St. Faustina\u2019s " +
                        "direction; public domain.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = "Jesus Prayer Illustration") {
                Text(
                    "Christ Pantocrator: encaustic icon (6th century), Saint Catherine\u2019s Monastery, " +
                        "Mount Sinai \u2014 the oldest surviving icon of Christ Pantocrator, honoring the " +
                        "prayer\u2019s Eastern tradition; public domain.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AboutSection(title = "Scripture Sources") {
                Text(
                    "Scripture quotations use the Douay-Rheims Bible (English), the Clementine Vulgate (Latin), " +
                        "Franz Delitzsch's Hebrew New Testament translation (sourced from kirjasilta.net/ha-berit) " +
                        "with Hebrew Old Testament passages following the Masoretic text, " +
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

private val sevenSorrowsAttributions = listOf(
    "*The Prophecy of Simeon* — Rembrandt van Rijn, Simeon\u2019s Song of Praise (1631), Mauritshuis — public domain.",
    "*The Flight into Egypt* — Bartolom\u00E9 Esteban Murillo (c. 1647\u201350), Detroit Institute of Arts — public domain.",
    "*The Loss of Jesus in the Temple* — Paolo Veronese, Christ Among the Doctors (c. 1560), Museo del Prado — public domain.",
    "*The Meeting on the Way of the Cross* — Raphael, Lo Spasimo (c. 1514\u201316), Museo del Prado — public domain.",
    "*The Crucifixion* — Hendrick ter Brugghen, The Crucifixion with the Virgin and Saint John (c. 1625), Metropolitan Museum of Art — CC0.",
    "*The Descent from the Cross* — Peter Paul Rubens (c. 1612\u201314), Cathedral of Our Lady, Antwerp — public domain.",
    "*The Burial of Jesus* — Titian, The Entombment of Christ (c. 1520), Mus\u00E9e du Louvre — public domain.",
)
