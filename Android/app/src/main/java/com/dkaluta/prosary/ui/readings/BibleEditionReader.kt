package com.dkaluta.prosary.ui.readings

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebResourceRequest
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.*
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.typography.PrayerTypography
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

internal data class BibleReaderSection(val book: BibleBook, val display: BibleDisplayChapter) {
    val id: String get() = "${book.id}/${display.chapter.chapter}"
}
private class EditionMessages(private val receive: (String) -> Unit) {
    @JavascriptInterface fun postMessage(value: String) = receive(value)
}

/** Native chrome and notes surround one offline text document for the entire edition. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
internal fun BibleEditionReader(edition: BibleEdition, sections: List<BibleReaderSection>, script: String,
    anchor: String, jumpSerial: Int, onPosition: (String, Int, String) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val chrome = LocalBibleReadingChrome.current
    val openUri = LocalUriHandler.current
    val density = LocalDensity.current
    val sample = sections.firstOrNull()?.display?.items?.firstNotNullOfOrNull { it.primary?.displayedText(edition.readingEdition(), script) }.orEmpty()
    val textScript = PrayerTypography.scriptOf(sample)
    val rtl = textScript in listOf(PrayerTypography.Script.Hebrew, PrayerTypography.Script.Arabic, PrayerTypography.Script.Syriac)
    val size = PrayerTypography.styleForText(sample, true).fontSize.value * density.fontScale
    val font = when (textScript) {
        PrayerTypography.Script.Hebrew -> when (AppSettings.hebrewScriptureTypeface) {
            AppSettings.TYPEFACE_STAM_ASHKENAZ -> R.font.stam_ashkenaz_clm
            AppSettings.TYPEFACE_STAM_SEFARAD -> R.font.stam_sefarad_clm
            AppSettings.TYPEFACE_RASHI -> R.font.noto_rashi_hebrew_regular
            else -> R.font.shofar_regular
        }
        PrayerTypography.Script.Syriac -> when (AppSettings.syriacTypeface) {
            AppSettings.TYPEFACE_WESTERN -> R.font.noto_sans_syriac_western_regular
            AppSettings.TYPEFACE_EASTERN -> R.font.noto_sans_syriac_eastern_regular
            else -> R.font.noto_sans_syriac_regular
        }
        PrayerTypography.Script.Arabic -> R.font.scheherazade_new_regular
        else -> R.font.cardo_regular
    }
    var web by remember { mutableStateOf<WebView?>(null) }
    var page by remember { mutableIntStateOf(1) }
    var total by remember { mutableIntStateOf(0) }
    var leaves by remember { mutableIntStateOf(1) }
    var note by remember { mutableStateOf<BibleDisplayItem?>(null) }
    val currentPosition by rememberUpdatedState(onPosition)
    val notes = remember(sections) { sections.flatMap { s -> s.display.items.map { s.id + "/" + it.id to it } }.toMap() }
    val html by produceState("", edition.revision, sections, script, size, font) {
        total = 0
        value = withContext(Dispatchers.Default) { editionHtml(context, edition, sections, script, anchor, rtl, size, font) }
    }
    fun command(value: JSONObject) { web?.evaluateJavascript("window.ProsaryReader?.command($value)", null) }
    LaunchedEffect(jumpSerial) { command(JSONObject().put("type", "jump").put("id", anchor)) }
    val label = stringResource(R.string.bible_page_count, page, minOf(page + leaves - 1, maxOf(1, total)), maxOf(1, total))
    Column(modifier.fillMaxSize().testTag("bibleEditionReader")) {
        Box(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 20.dp)) {
            if (html.isNotEmpty()) AndroidView(modifier = Modifier.fillMaxSize().testTag("bibleEditionText"), factory = { owner ->
                WebView(owner).apply {
                    setBackgroundColor(Color.TRANSPARENT)
                    settings.javaScriptEnabled = true
                    settings.allowFileAccess = false
                    settings.allowContentAccess = false
                    settings.blockNetworkLoads = true
                    val taps = android.view.GestureDetector(owner, object : android.view.GestureDetector.SimpleOnGestureListener() {
                        override fun onDown(event: android.view.MotionEvent): Boolean = true
                        override fun onSingleTapUp(event: android.view.MotionEvent): Boolean {
                            if (event.getToolType(0) != android.view.MotionEvent.TOOL_TYPE_FINGER) return false
                            val scale = resources.displayMetrics.density
                            evaluateJavascript("window.getSelection().isCollapsed && !document.elementFromPoint(${event.x / scale},${event.y / scale})?.closest('a,[data-note]')") { allowed ->
                                if (allowed == "true") chrome?.let { it.value = !it.value }
                            }
                            return false
                        }
                    })
                    setOnTouchListener { _, event -> taps.onTouchEvent(event); false }
                    webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean = true
                    }
                    addJavascriptInterface(EditionMessages { raw -> post {
                        val message = runCatching { JSONObject(raw) }.getOrNull() ?: return@post
                        when (message.optString("type")) {
                            "state" -> { page = message.getInt("page"); total = message.getInt("total"); leaves = message.getInt("leaves")
                                currentPosition(message.getString("book"), message.getInt("chapter"), message.getString("anchor")) }
                            "chrome" -> chrome?.let { it.value = if (message.has("hidden")) message.getBoolean("hidden") else !it.value }
                            "note" -> note = notes[message.optString("id")]
                            "link" -> message.optString("url").takeIf { it.startsWith("https://") }?.let(openUri::openUri)
                        }
                    } }, "ProsaryHost")
                    tag = html; loadDataWithBaseURL(null, html, "text/html", "UTF-8", null); web = this
                }
            }, onRelease = { it.removeJavascriptInterface("ProsaryHost"); it.destroy(); web = null }, update = {
                if (it.tag != html) { it.tag = html; it.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null) }
            })
            if (total == 0) CircularProgressIndicator(Modifier.testTag("biblePreparingEdition"))
        }
        if (chrome?.value != true) {
        CompositionLocalProvider(LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 12.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                IconButton(onClick = { command(JSONObject().put("type", "turn").put("delta", -1)) }, enabled = page > 1,
                    modifier = Modifier.testTag("biblePreviousPage")) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.bible_previous_page)) }
                Text(label, Modifier.weight(1f).testTag("biblePageCount"), style = MaterialTheme.typography.labelMedium,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                IconButton(onClick = { command(JSONObject().put("type", "turn").put("delta", 1)) }, enabled = total > 0 && page + leaves <= total,
                    modifier = Modifier.testTag("bibleNextPage")) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.bible_next_page)) }
            }
            if (total > 1) Slider(page.toFloat(), { command(JSONObject().put("type", "page").put("page", it.toInt() - 1)) },
                valueRange = 1f..total.toFloat(), modifier = Modifier.padding(horizontal = 20.dp).testTag("biblePageSlider"))
        }
    }
    }
    note?.let { selected -> AlertDialog(onDismissRequest = { note = null },
        text = { Column(Modifier.verticalScroll(rememberScrollState())) { ScriptureSourceNotes(selected.sourceNotes) } },
        confirmButton = { TextButton(onClick = { note = null }) { Text(stringResource(R.string.common_done)) } }) }
}

private fun editionHtml(context: Context, edition: BibleEdition, sections: List<BibleReaderSection>, script: String,
    anchor: String, rtl: Boolean, size: Float, font: Int): String {
    val content = JSONArray()
    for (section in sections) {
        val book = section.book
        val info = book.chapters.first { it.number == section.display.chapter.chapter }
        val blocks = JSONArray()
        for (item in section.display.items) {
            val unit = item.primary
            val label = unit?.let { if (it.chapter == info.number) it.verseLabel else BibleNavigation.sourceLabel(it, info.number) {
                ReadingChapterHeading.number(it, edition.languageCode, script)
            } } ?: item.block.printedLabel.orEmpty()
            val printed = item.block.printedLabel ?: label.takeIf { unit != null && info.canonicalReference != null }
            blocks.put(JSONObject().put("id", section.id + "/" + item.id).put("kind", item.block.kind)
                .put("text", unit?.displayedText(edition.readingEdition(), script) ?: item.block.text.orEmpty())
                .put("label", if (unit != null && info.canonicalReference != null) "" else label)
                .put("printed", printed?.let { context.getString(R.string.bible_printed_label, it) }.orEmpty())
                .put("notes", !item.sourceNotes.isNullOrEmpty()))
        }
        content.put(JSONObject().put("id", section.id).put("book", book.id).put("bookName", book.displayedName(script))
            .put("chapter", info.number).put("label", info.canonicalReference ?: ReadingChapterHeading.label(context, info.number, edition.languageCode, script))
            .put("partial", !info.isComplete).put("introduction", book.introduction?.takeIf { info.number == book.chapters.first().number }.orEmpty())
            .put("attribution", book.attribution.orEmpty()).put("sourceURL", book.sourceURL.orEmpty()).put("blocks", blocks))
    }
    val payload = JSONObject().put("title", edition.name).put("language", edition.languageCode).put("rtl", rtl)
        .put("fontSize", size).put("font", Base64.encodeToString(context.resources.openRawResource(font).use { it.readBytes() }, Base64.NO_WRAP))
        .put("anchor", anchor).put("chromeTaps", false).put("interfaceRTL", context.resources.configuration.layoutDirection == android.view.View.LAYOUT_DIRECTION_RTL).put("sections", content).put("attribution", edition.attribution).put("sourceURL", edition.sourceURL)
        .put("partialLabel", context.getString(R.string.bible_partial_chapter)).put("sourceLabel", context.getString(R.string.readings_source))
        .put("noteLabel", context.getString(R.string.scripture_source_note))
    return context.assets.open("edition-reader.html").bufferedReader().use { it.readText() }
        .replace("__PROSARY_DOCUMENT__", payload.toString().replace("<", "\\u003c"))
}
