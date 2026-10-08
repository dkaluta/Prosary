package com.dkaluta.prosary

import android.os.Bundle
import android.os.Build
import android.Manifest
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.ProsaryApp
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.Lifecycle
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MultiDayRuns
import com.dkaluta.prosary.widgets.WidgetDestination
import com.dkaluta.prosary.widgets.WidgetLaunchRequest
import com.dkaluta.prosary.widgets.WidgetUpdates
import com.dkaluta.prosary.ui.shared.PrayerVolumeAction
import com.dkaluta.prosary.ui.shared.PrayerVolumeNavigation
import com.dkaluta.prosary.ui.shared.PrayerVolumeNavigationTarget

class MainActivity : AppCompatActivity() {
    private var widgetLaunchRequest by mutableStateOf<WidgetLaunchRequest?>(null)
    private val volumeNavigation = PrayerVolumeNavigation()
    private var volumeNavigationTarget: PrayerVolumeNavigationTarget? = null

    /** Readers register while composed; disposal cannot remove a newer reader's registration. */
    internal fun registerPrayerVolumeNavigation(target: PrayerVolumeNavigationTarget): () -> Unit {
        volumeNavigationTarget = target
        return { if (volumeNavigationTarget === target) volumeNavigationTarget = null }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_UP && event.keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return super.dispatchKeyEvent(event)
        }
        val target = volumeNavigationTarget
        val readerActive = target?.readerActive?.invoke() == true && hasWindowFocus() &&
            lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) && currentFocus !is EditText &&
            currentFocus?.onCheckIsTextEditor() != true
        val audioActive = target?.audioActive?.invoke() == true ||
            (AppSettings.volumeButtonNavigationEnabled && readerActive && systemAudioIsActive())
        val action = volumeNavigation.action(
            keyCode = event.keyCode,
            keyAction = event.action,
            repeatCount = event.repeatCount,
            downTime = event.downTime,
            enabled = AppSettings.volumeButtonNavigationEnabled,
            readerActive = readerActive,
            audioActive = audioActive,
            canGoBack = target?.canGoBack?.invoke() == true,
            hasModifiers = event.isShiftPressed || event.isAltPressed || event.isCtrlPressed ||
                event.isMetaPressed || event.isSymPressed || event.isFunctionPressed,
            canceled = event.isCanceled,
        )
        when (action) {
            PrayerVolumeAction.Previous -> target?.onBack?.invoke()
            PrayerVolumeAction.Next -> target?.onNext?.invoke()
            else -> Unit
        }
        return action != PrayerVolumeAction.Ignore || super.dispatchKeyEvent(event)
    }

    private fun systemAudioIsActive(): Boolean {
        val manager = getSystemService(AudioManager::class.java) ?: return true
        // Includes another app's media, calls/ringing, and (on Oreo+) alarm/notification audio.
        // If the device cannot report its playback state, preserve native volume control.
        return runCatching {
            manager.isMusicActive || manager.mode != AudioManager.MODE_NORMAL ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.activePlaybackConfigurations.isNotEmpty())
        }.getOrDefault(true)
    }
    // A completed day leaves its flow immediately. Register on the Activity so the permission
    // result still arrives after that navigation, then restore all newly permitted reminders.
    private val seriesReminderPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) lifecycleScope.launch(Dispatchers.IO) {
            val services = AppServices.create(applicationContext)
            ReminderScheduler.rescheduleAll(applicationContext, services.presetStore.all())
        }
    }

    fun requestSeriesReminderPermission(devotionId: String) {
        val dayCount = PrayerPackStore.definition(devotionId)?.days?.size ?: return
        val run = MultiDayRuns.run(this, devotionId) ?: return
        if (run.isComplete(dayCount)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !ReminderScheduler.hasNotificationPermission(this)) {
            seriesReminderPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        AppSettings.init(this)
        LauncherIconController.synchronize(this)
        InterfaceLanguageController.synchronize(this)
        readWidgetIntent(intent)
        WidgetUpdates.refresh(this)
        ReminderScheduler.createNotificationChannel(this)

        setContent {
            val services by produceState<AppServices?>(initialValue = AppServices.cached()) {
                if (value == null) {
                    value = withContext(Dispatchers.IO) {
                        AppServices.create(applicationContext)
                    }
                }
            }
            ProsaryTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    val loadedServices = services
                    if (loadedServices == null) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else {
                        CompositionLocalProvider(LocalAppServices provides loadedServices) {
                            ProsaryApp(widgetLaunchRequest = widgetLaunchRequest, onWidgetLaunchConsumed = {
                                widgetLaunchRequest = null
                                // A restored Activity must not replay a widget tap already handled.
                                setIntent(Intent(intent).setData(null))
                            })
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readWidgetIntent(intent)
    }

    private fun readWidgetIntent(intent: Intent?) {
        WidgetDestination.parse(intent?.dataString)?.let {
            widgetLaunchRequest = WidgetLaunchRequest(it, System.nanoTime())
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) WidgetUpdates.refresh(applicationContext)
    }
}
