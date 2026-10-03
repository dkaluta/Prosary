package com.dkaluta.prosary.content.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Locale

/** Native speech fallback. Only a matching, installed offline voice may read prayer text. */
class PrayerSpeechController(context: Context) {
    var isSpeaking by mutableStateOf(false)
        private set
    var isReady by mutableStateOf(false)
        private set
    var failed by mutableStateOf(false)
        private set
    private val main = Handler(Looper.getMainLooper())
    private val audioManager = context.applicationContext.getSystemService(AudioManager::class.java)
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
        .setOnAudioFocusChangeListener { if (it < 0) stop() }.build()
    private var engine: TextToSpeech? = null
    private var generation = 0L
    private var lastUtterance: String? = null
    private var disposed = false

    init {
        engine = TextToSpeech(context.applicationContext) { status ->
            main.post {
                if (!disposed) {
                    isReady = status == TextToSpeech.SUCCESS
                    failed = !isReady
                }
            }
        }.also { tts ->
            tts.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit
                override fun onDone(utteranceId: String?) { main.post {
                    if (utteranceId == lastUtterance) stop()
                } }
                @Deprecated("Required by the system callback contract")
                override fun onError(utteranceId: String?) { main.post {
                    if (utteranceId?.startsWith("$generation:") == true) {
                        stop()
                        failed = true
                    }
                } }
            })
        }
    }

    private fun voice(languageCode: String) = engine?.voices.orEmpty()
        .filter { !it.isNetworkConnectionRequired &&
            it.features?.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) != true &&
            PrayerSpeechText.voiceMatches(it.locale.language, languageCode) }
        .sortedWith(compareByDescending<android.speech.tts.Voice> { it.locale == Locale.getDefault() }
            .thenByDescending { it.quality }.thenBy { it.name }).firstOrNull()

    fun canSpeak(languageCode: String?) = isReady && languageCode != null && voice(languageCode) != null

    fun speak(text: String, languageCode: String?): Boolean {
        stop()
        failed = false
        val tts = engine ?: return false
        val selected = languageCode?.let(::voice) ?: return false
        val chunks = PrayerSpeechText.chunks(text, TextToSpeech.getMaxSpeechInputLength())
        if (!isReady || chunks.isEmpty() || tts.setVoice(selected) != TextToSpeech.SUCCESS) return false
        if (audioManager.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return false
        generation++
        lastUtterance = "$generation:${chunks.lastIndex}"
        isSpeaking = true
        chunks.forEachIndexed { index, chunk ->
            if (tts.speak(chunk, if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD,
                    null, "$generation:$index") == TextToSpeech.ERROR) {
                stop()
                failed = true
                return false
            }
        }
        return true
    }

    fun stop() {
        generation++
        lastUtterance = null
        engine?.stop()
        isSpeaking = false
        audioManager.abandonAudioFocusRequest(focus)
    }

    fun dispose() {
        disposed = true
        stop()
        engine?.shutdown()
        engine = null
    }
}

/** Kept independent of Android services for language and long-text regression tests. */
object PrayerSpeechText {
    fun baseLanguage(code: String): String = when (val base = code.replace('_', '-').lowercase(Locale.ROOT).substringBefore('-')) {
        "iw" -> "he"
        "fil" -> "tl"
        else -> base
    }
    fun voiceMatches(voiceLanguage: String, prayerLanguage: String): Boolean =
        baseLanguage(prayerLanguage).let { it.isNotEmpty() && baseLanguage(voiceLanguage) == it }

    fun chunks(text: String, limit: Int): List<String> {
        require(limit >= 2)
        var remaining = text.replace("**", "").trim()
        val result = mutableListOf<String>()
        while (remaining.length > limit) {
            var end = remaining.lastIndexOfAny(charArrayOf(' ', '\n'), startIndex = limit)
            if (end < limit / 2) end = limit
            if (remaining[end - 1].isHighSurrogate()) end--
            result += remaining.substring(0, end).trim()
            remaining = remaining.substring(end).trim()
        }
        if (remaining.isNotEmpty()) result += remaining
        return result
    }
}
