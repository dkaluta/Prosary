package com.dkaluta.prosary.ui.readings

import com.dkaluta.prosary.ui.shared.AramaicScriptPicker

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleCatalog
import com.dkaluta.prosary.content.bible.BibleDisplayChapter
import com.dkaluta.prosary.content.bible.BibleSourceStructure
import com.dkaluta.prosary.content.bible.BibleEdition
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.bible.BibleNavigation
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.typography.PrayerTypography
import java.io.InputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private data class BibleCatalogState(val loaded: Boolean = false, val catalog: BibleCatalog? = null)
private data class InstalledBibleState(val loaded: Boolean = false, val edition: BibleEdition? = null)
private data class BibleChapterState(val loaded: Boolean = false, val chapter: BibleDisplayChapter? = null)
private data class BibleEditionState(val loaded: Boolean = false, val sections: List<BibleReaderSection>? = null)

@Composable
internal fun BibleScreen(
    library: BibleLibrary = BibleLibrary.get(LocalContext.current),
    openCatalog: (() -> InputStream)? = null,
) {
    val context = LocalContext.current
    val language = TodayTranslationLanguage.resolve(LocalConfiguration.current.locales[0].toLanguageTag())
    var reload by remember { mutableIntStateOf(0) }
    val catalogState by produceState(BibleCatalogState(), library, reload) {
        value = withContext(Dispatchers.IO) {
            BibleCatalogState(true, runCatching {
                library.store.catalog(openCatalog?.invoke() ?: context.assets.open("data/bible-catalog.json"))
            }.getOrNull())
        }
    }
    val catalog = catalogState.catalog
    val editions = catalog?.editions.orEmpty()
    val selectedId = ReadingTextStore.effectiveEditionId(AppSettings.readingsEditionId, language, editions.map { it.readingEdition() })
    val edition = editions.firstOrNull { it.id == selectedId }
    var showEditions by remember { mutableStateOf(false) }
    val generation by library.generation.collectAsStateWithLifecycle()
    val downloads by library.downloads.collectAsStateWithLifecycle()
    val installation by key(selectedId, generation[selectedId]) {
        produceState(InstalledBibleState()) {
            value = withContext(Dispatchers.IO) { InstalledBibleState(true, selectedId?.let(library.store::installedEdition)) }
        }
    }
    var removeEdition by remember { mutableStateOf<BibleEdition?>(null) }
    val chrome = LocalBibleReadingChrome.current ?: remember { mutableStateOf(false) }
    androidx.compose.runtime.DisposableEffect(chrome) { onDispose { chrome.value = false } }

    CompositionLocalProvider(LocalBibleReadingChrome provides chrome) {
    Column(Modifier.fillMaxSize().testTag("bibleScreen")) {
        if (!chrome.value) Box(Modifier.padding(horizontal = 16.dp)) {
            TextButton(onClick = { showEditions = true }, modifier = Modifier.testTag("bibleEdition")) {
                Text("${stringResource(R.string.readings_edition)}: ${edition?.name ?: stringResource(R.string.readings_choose_edition)}")
            }
            DropdownMenu(expanded = showEditions, onDismissRequest = { showEditions = false }) {
                DropdownMenuItem(text = { Text(stringResource(R.string.readings_follow_interface)) }, onClick = {
                    AppSettings.readingsEditionId = ""; showEditions = false
                })
                for (available in editions) DropdownMenuItem(text = { Text(available.name) }, onClick = {
                    AppSettings.readingsEditionId = available.id; showEditions = false
                })
            }
        }
        when {
            !catalogState.loaded || !installation.loaded -> CircularProgressIndicator(Modifier.padding(16.dp))
            catalog == null -> Column(Modifier.padding(16.dp)) {
                Text(stringResource(R.string.bible_catalog_error))
                TextButton(onClick = { reload++ }) { Text(stringResource(R.string.common_retry)) }
            }
            edition == null -> Text(stringResource(R.string.readings_choose_edition), Modifier.padding(16.dp))
            else -> {
                val installed = installation.edition
                val download = downloads[edition.id]
                if (!chrome.value) Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (download != null && !download.failed) {
                        Text(stringResource(R.string.bible_downloading), style = MaterialTheme.typography.labelLarge)
                        LinearProgressIndicator(progress = { download.progress }, modifier = Modifier.fillMaxWidth().testTag("bibleDownloadProgress"))
                        TextButton(onClick = { library.cancel(edition.id) }) { Text(stringResource(R.string.common_cancel)) }
                    } else {
                        if (download?.failed == true) Text(stringResource(if (download.removalFailed) R.string.bible_remove_error else R.string.bible_download_error), color = MaterialTheme.colorScheme.error)
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (installed?.revision != edition.revision) Button(
                                onClick = { library.download(edition) }, modifier = Modifier.testTag("bibleDownload"),
                            ) { Text(stringResource(if (download?.failed == true) R.string.common_retry
                                else if (installed != null) R.string.common_update else R.string.bible_download)) }
                            if (installed != null) TextButton(onClick = { removeEdition = installed }, modifier = Modifier.testTag("bibleRemoveDownload")) {
                                Text(stringResource(R.string.download_remove_action))
                            }
                        }
                    }
                }
                if (installed == null) {
                    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        item { Text(stringResource(R.string.bible_download_notice)) }
                        item { BibleSourceCredit(edition.attribution, edition.sourceURL) }
                    }
                } else key(installed.id, installed.revision) {
                    BibleInstalledReader(installed, library, Modifier.weight(1f))
                }
            }
        }
    }
    }
    removeEdition?.let { removing ->
        AlertDialog(onDismissRequest = { removeEdition = null },
            title = { Text(stringResource(R.string.download_remove_title)) },
            text = { Text(stringResource(R.string.bible_remove_notice, removing.name)) },
            confirmButton = { TextButton(onClick = { library.remove(removing.id); removeEdition = null }) {
                Text(stringResource(R.string.settings_remove_all_confirm))
            } },
            dismissButton = { TextButton(onClick = { removeEdition = null }) { Text(stringResource(R.string.common_cancel)) } })
    }
}

@Composable
private fun BibleInstalledReader(edition: BibleEdition, library: BibleLibrary, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val interfaceDirection = LocalLayoutDirection.current
    var selectedBook by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedChapter by rememberSaveable { mutableStateOf<Int?>(null) }
    var scriptOverride by rememberSaveable { mutableStateOf<String?>(null) }
    var picker by rememberSaveable { mutableStateOf<String?>(null) }
    var readingAnchor by rememberSaveable { mutableStateOf("notice") }
    var verseJump by remember { mutableStateOf<String?>(null) }
    var jumpSerial by remember { mutableIntStateOf(0) }
    val script = scriptOverride ?: AppSettings.aramaicDefaultScript
    val readingEdition = remember(edition) { edition.readingEdition() }
    val position = BibleNavigation.resolve(edition, selectedBook, selectedChapter)
    val book = edition.books.first { it.id == position.book }
    val info = book.chapters.first { it.number == position.chapter }
    val editionState by produceState(BibleEditionState(), edition.id, edition.revision) {
        value = withContext(Dispatchers.IO) {
            BibleEditionState(true, runCatching {
                edition.books.flatMap { book -> book.chapters.map { info ->
                    BibleReaderSection(book, requireNotNull(library.store.displayChapter(edition, book.id, info.number)))
                } }
            }.getOrNull())
        }
    }
    val chapterState = BibleChapterState(editionState.loaded,
        editionState.sections?.firstOrNull { it.book.id == book.id && it.display.chapter.chapter == info.number }?.display)
    val chapter = chapterState.chapter
    val scope = rememberCoroutineScope()
    val scroll = rememberLazyListState()
    fun navigate(next: BibleNavigation.Position, atEnd: Boolean = false) {
        selectedBook = next.book
        selectedChapter = next.chapter
        picker = null
        readingAnchor = "${next.book}/${next.chapter}"
        verseJump = null
        jumpSerial++
        scope.launch { scroll.scrollToItem(0) }
    }
    val previous = BibleNavigation.neighbor(edition, position, -1)
    val next = BibleNavigation.neighbor(edition, position, 1)
    val chromeHidden = LocalBibleReadingChrome.current?.value == true
    Column(modifier) {
        if (!chromeHidden) {
        FlowRow(Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            TextButton(onClick = { picker = "book" }, modifier = Modifier.testTag("bibleBook")) { Text(book.displayedName(script)) }
            TextButton(onClick = { picker = "chapter" }, modifier = Modifier.testTag("bibleChapter")) {
                Text(info.canonicalReference ?: ReadingChapterHeading.label(context, info.number, edition.languageCode, script))
            }
            TextButton(onClick = { picker = "verse" }, enabled = chapter != null, modifier = Modifier.testTag("bibleVerse")) {
                Text(stringResource(R.string.bible_choose_verse))
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { previous?.let { navigate(it) } }, enabled = previous != null, modifier = Modifier.testTag("biblePreviousChapter")) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.bible_previous_chapter))
            }
            if (readingEdition.hasAramaicScripts) {
                AramaicScriptPicker(script, onSelect = { scriptOverride = it },
                    modifier = Modifier.weight(1f).testTag("bibleScript"))
            } else Box(Modifier.weight(1f))
            IconButton(onClick = { next?.let { navigate(it) } }, enabled = next != null, modifier = Modifier.testTag("bibleNextChapter")) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.bible_next_chapter))
            }
        }
        }
        when {
            !chapterState.loaded -> CircularProgressIndicator(Modifier.padding(16.dp))
            chapter == null -> Text(stringResource(R.string.bible_chapter_error), Modifier.padding(16.dp))
            else -> {
                BibleEditionReader(edition, requireNotNull(editionState.sections), script, readingAnchor, jumpSerial,
                    onPosition = { bookID, chapterNumber, block ->
                        selectedBook = bookID; selectedChapter = chapterNumber; readingAnchor = block
                    }, modifier = Modifier.weight(1f))
            }
        }
    }
    when (picker) {
        "book" -> BibleChoiceDialog(stringResource(R.string.bible_choose_book), edition.books.map { it.id to it.displayedName(script) },
            onDismiss = { picker = null }, onSelect = { id -> navigate(BibleNavigation.resolve(edition, id, null)) })
        "chapter" -> BibleChoiceDialog(stringResource(R.string.bible_choose_chapter), book.chapters.map {
            it.number.toString() to (it.canonicalReference ?: ReadingChapterHeading.label(context, it.number, edition.languageCode, script))
        }, onDismiss = { picker = null }, onSelect = { number -> navigate(BibleNavigation.Position(book.id, number.toInt())) })
        "verse" -> BibleChoiceDialog(stringResource(R.string.bible_choose_verse), bibleVerseChoices(chapter, edition, script),
            onDismiss = { picker = null }, onSelect = { choice ->
            picker = null
            val index = if (chapter?.chapter?.contentBlocks == null) {
                chapter?.items?.indexOfFirst { choice.toIntOrNull()?.let { number ->
                    it.primary?.let { unit -> number in unit.verse..unit.lastVerse }
                } == true } ?: -1
            } else chapter.items.indexOfFirst { it.id == choice }
            if (index >= 0) {
                readingAnchor = "${book.id}/${info.number}/${requireNotNull(chapter).items[index].id}"
                verseJump = readingAnchor
                jumpSerial++
            }
        })
    }
}

@Composable
private fun BibleSourceBlock(item: com.dkaluta.prosary.content.bible.BibleDisplayItem,
    readingEdition: com.dkaluta.prosary.content.today.ReadingEdition, script: String,
    info: com.dkaluta.prosary.content.bible.BibleChapterInfo, edition: BibleEdition,
    direction: LayoutDirection, interfaceDirection: LayoutDirection) {
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        Column(Modifier.testTag("bibleBlock.${item.id}")) {
            val verse = item.primary
            val text = verse?.displayedText(readingEdition, script) ?: item.block.text.orEmpty()
            when (item.block.kind) {
                "heading" -> DisableSelection {
                    Text(text, style = PrayerTypography.styleForText(text, isScripture = true),
                        fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth())
                }
                "colophon" -> DisableSelection {
                    Text(text, style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.fillMaxWidth())
                }
                else -> {
                    val sourceLabel = verse?.let { unit ->
                        if (unit.chapter == info.number) unit.verseLabel
                        else BibleNavigation.sourceLabel(unit, info.number) { ReadingChapterHeading.number(it, edition.languageCode, script) }
                    } ?: item.block.printedLabel
                    val usesPrintedLabels = verse != null && info.canonicalReference != null
                    val display = if (sourceLabel == null || usesPrintedLabels) text else "\u2068$sourceLabel\u2069  $text"
                    val bodyModifier = Modifier.fillMaxWidth().then(if (verse != null) Modifier.testTag("bibleVerse.${verse.verse}") else Modifier)
                    if (LocalBibleBookMode.current) {
                        Text(BibleBookTypography.body(text, sourceLabel.takeUnless { usesPrintedLabels }),
                            style = PrayerTypography.styleForText(text, isScripture = true),
                            textAlign = TextAlign.Justify, modifier = bodyModifier)
                    } else {
                        Text(display, style = PrayerTypography.styleForText(text, isScripture = true), modifier = bodyModifier)
                    }
                    if (verse != null) (item.block.printedLabel ?: sourceLabel.takeIf { usesPrintedLabels })?.let { printed ->
                        DisableSelection { CompositionLocalProvider(LocalLayoutDirection provides interfaceDirection) {
                            Text(stringResource(R.string.bible_printed_label, "\u2068$printed\u2069"),
                                style = MaterialTheme.typography.labelMedium,
                                modifier = Modifier.testTag("biblePrintedLabel.${item.id}"))
                        } }
                    }
                }
            }
            ScriptureSourceNotes(item.sourceNotes)
        }
    }
}

@Composable
private fun bibleVerseChoices(chapter: BibleDisplayChapter?, edition: BibleEdition, script: String): List<Pair<String, String>> {
    if (chapter == null) return emptyList()
    val usesPrintedLabels = edition.books.first { it.id == chapter.chapter.book }.chapters
        .first { it.number == chapter.chapter.chapter }.canonicalReference != null
    @Composable fun numericLabel(value: String): String = if (usesPrintedLabels)
        stringResource(R.string.bible_printed_label, "\u2068$value\u2069") else value
    if (chapter.chapter.contentBlocks == null) return chapter.items.flatMap { item ->
        val verse = requireNotNull(item.primary)
        (verse.verse..verse.lastVerse).map { it.toString() to numericLabel(
            if (usesPrintedLabels) verse.verseLabel else ReadingChapterHeading.number(it, edition.languageCode, script)) }
    }
    return chapter.items.mapIndexedNotNull { index, item ->
        val primary = item.primary
        when (item.block.kind) {
            "verse" -> {
                val unit = requireNotNull(primary)
                val sourceLabel = if (usesPrintedLabels && unit.chapter == chapter.chapter.chapter) unit.verseLabel
                    else BibleNavigation.sourceLabel(unit, chapter.chapter.chapter) { ReadingChapterHeading.number(it, edition.languageCode, script) }
                item.id to numericLabel(if (usesPrintedLabels) item.block.printedLabel ?: sourceLabel else sourceLabel)
            }
            "witness" -> {
                val literal = "\u2068${item.block.printedLabel}\u2069"
                val occurrence = BibleSourceStructure.occurrence(chapter.items, index)
                item.id to if (occurrence == null) literal else stringResource(R.string.bible_occurrence, literal, occurrence)
            }
            else -> null
        }
    }
}

@Composable
private fun BibleChoiceDialog(title: String, choices: List<Pair<String, String>>, onDismiss: () -> Unit, onSelect: (String) -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text(title) },
        text = {
            LazyColumn(Modifier.heightIn(max = 420.dp).testTag("bibleChoices")) {
                items(choices, key = { it.first }) { (id, name) ->
                    TextButton(onClick = { onSelect(id) }, modifier = Modifier.fillMaxWidth().testTag("bibleChoice.$id")) { Text(name) }
                }
            }
        }, confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } })
}

@Composable
private fun BibleSourceCredit(attribution: String, url: String?) {
    val uriHandler = LocalUriHandler.current
    Text(attribution, style = MaterialTheme.typography.bodySmall)
    if (url?.startsWith("https://") == true) TextButton(onClick = { uriHandler.openUri(url) }) {
        Text(stringResource(R.string.readings_source))
    }
}
