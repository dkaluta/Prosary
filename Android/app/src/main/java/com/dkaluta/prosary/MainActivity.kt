package com.dkaluta.prosary

import android.os.Bundle
import android.os.Build
import android.Manifest
import android.content.Intent
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
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MultiDayRuns
import com.dkaluta.prosary.widgets.WidgetDestination
import com.dkaluta.prosary.widgets.WidgetLaunchRequest
import com.dkaluta.prosary.widgets.WidgetUpdates

class MainActivity : AppCompatActivity() {
    private var widgetLaunchRequest by mutableStateOf<WidgetLaunchRequest?>(null)
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
