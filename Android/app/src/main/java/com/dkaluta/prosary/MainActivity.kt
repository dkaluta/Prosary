package com.dkaluta.prosary

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
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

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        AppSettings.init(this)
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
                            ProsaryApp()
                        }
                    }
                }
            }
        }
    }
}
