package com.dkaluta.prosary.testing

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.State
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.lifecycle.ViewModelProvider
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.jesusprayer.JesusPrayerFlowScreen
import com.dkaluta.prosary.ui.rosaryflow.RosaryFlowScreen
import com.dkaluta.prosary.ui.shared.CustomDevotionFlowScreen
import com.dkaluta.prosary.ui.shared.CustomDevotionPrayerSession
import com.dkaluta.prosary.ui.shared.PrayerFlowChromeState
import com.dkaluta.prosary.ui.shared.RosaryPrayerSession
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import java.io.File

/** Debug-only recreation harness. It never opens Room or the user's preference/pack folders. */
class PrayerSessionTestActivity : ComponentActivity() {
    companion object {
        private var creationSerial = 0
    }
    var creationNumberForTest = 0
        private set
    private lateinit var navigation: NavHostController
    private lateinit var testContext: Context
    private lateinit var prayer: Prayer
    private lateinit var devotionId: String
    private val preferenceFiles = mutableSetOf<String>()
    private var readingDensity: Density? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        creationNumberForTest = ++creationSerial
        val runId = requireNotNull(intent.getStringExtra("runId"))
        val mode = intent.getStringExtra("mode") ?: "rosary"
        testContext = object : ContextWrapper(this) {
            override fun getApplicationContext(): Context = this
            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
                val isolatedName = "prayer-session-test-$runId-$name"
                preferenceFiles += isolatedName
                return super.getSharedPreferences(isolatedName, mode)
            }
            override fun getFilesDir(): File = File(super.getFilesDir(), "prayer-session-test/$runId").also { it.mkdirs() }
            override fun getCacheDir(): File = File(super.getCacheDir(), "prayer-session-test/$runId").also { it.mkdirs() }
        }
        AppSettings.init(testContext)
        if (savedInstanceState == null) {
            PrayerPackStore.resetForTesting()
            PrayerPackStore.installedPacksDirectory = File(testContext.filesDir, "prayerpacks")
            PrayerPackStore.initialize(assets)
            intent.getStringExtra("audioFixture")?.let { fixture ->
                PrayerPackStore.installPack(File(fixture).readBytes())
            }
        }
        devotionId = when (mode) {
            "audio" -> "kyrieaudiodemo"
            "days" -> "oAntiphons"
            "variant" -> "stationsOfTheCross"
            else -> "angelus"
        }
        prayer = Prayer(
            id = "prayer-session-test-$runId",
            name = "Test prayer",
            kind = when (mode) {
                "rosary" -> PrayerKind.Rosary
                "jesus" -> PrayerKind.JesusPrayer
                else -> PrayerKind.Custom
            },
            languageCode = "en",
            customDevotionId = devotionId,
            jesusPrayer = JesusPrayerOptions(target = JesusPrayerTarget.Count(33)),
        )
        val calendar = MockLiturgicalCalendar()
        val services = AppServices(MockPresetStore(listOf(prayer)), PrayerEngine(calendar), calendar)
        setContent {
            val density = LocalDensity.current
            val testDensity = if (intent.getBooleanExtra("largeText", false)) Density(density.density, 2f) else density
            readingDensity = testDensity
            CompositionLocalProvider(LocalContext provides testContext, LocalAppServices provides services,
                LocalDensity provides testDensity) {
                ProsaryTheme {
                    navigation = rememberNavController()
                    NavHost(navigation, startDestination = "landing") {
                        composable("landing") {
                            Button(onClick = { navigation.navigate("session") }) { Text("Open test prayer") }
                        }
                        composable("session") {
                            when (mode) {
                                "rosary" -> RosaryFlowScreen(prayer, { navigation.popBackStack() }, { _, _, _ -> navigation.popBackStack() })
                                "jesus" -> JesusPrayerFlowScreen(prayer = prayer,
                                    onNavigateUp = { navigation.popBackStack() }, onFinish = { navigation.popBackStack() })
                                else -> CustomDevotionFlowScreen(devotionId, prayer = prayer, onBack = { navigation.popBackStack() })
                            }
                            if (intent.getBooleanExtra("largeText", false)) {
                                LaunchedEffect(Unit) {
                                    snapshotFlow { readingMetricsForTest() }.collect { Log.i("ProsaryReadingTrace", it) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fun audioForTest(): AudioPlaybackController = ViewModelProvider(navigation.getBackStackEntry("session"))
        .get("custom:$devotionId:${prayer.id}", CustomDevotionPrayerSession::class.java).audio

    fun readingAnchorForTest(): Pair<Int, Int> = ViewModelProvider(navigation.getBackStackEntry("session"))
        .get(PrayerFlowChromeState::class.java).reading.run { firstVisibleItemIndex to firstVisibleItemScrollOffset }

    fun rosaryIndexForTest(): State<Int> = ViewModelProvider(navigation.getBackStackEntry("session"))
        .get(PrayerRunKeys.rosary(prayer.id), RosaryPrayerSession::class.java).currentIndex

    fun readingMetricsForTest(): String {
        val chrome = ViewModelProvider(navigation.getBackStackEntry("session")).get(PrayerFlowChromeState::class.java)
        val reading = chrome.reading
        val layout = reading.layoutInfo
        return "model=${System.identityHashCode(chrome)} activity=$creationNumberForTest " +
            "window=${resources.configuration.screenWidthDp}x${resources.configuration.screenHeightDp} " +
            "density=${readingDensity?.density}/${readingDensity?.fontScale} " +
            "anchor=${reading.firstVisibleItemIndex}/${reading.firstVisibleItemScrollOffset} " +
            "scrolling=${reading.isScrollInProgress} viewport=${layout.viewportSize} " +
            "start=${layout.viewportStartOffset} end=${layout.viewportEndOffset} total=${layout.totalItemsCount} " +
            "items=${layout.visibleItemsInfo.joinToString { "${it.index}:${it.offset}:${it.size}" }}"
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            // Restore the process-wide catalogs/preferences for any following app tests.
            PrayerPackStore.resetForTesting()
            PrayerPackStore.installedPacksDirectory = File(applicationContext.filesDir, "prayerpacks")
            PrayerPackStore.initialize(assets)
            AppSettings.init(applicationContext)
            preferenceFiles.forEach { deleteSharedPreferences(it) }
            testContext.filesDir.deleteRecursively()
            testContext.cacheDir.deleteRecursively()
        }
    }
}
