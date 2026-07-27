package com.dkaluta.prosary

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.ProsaryApp
import com.dkaluta.prosary.ui.theme.ProsaryTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        AppSettings.init(this)
        ReminderScheduler.createNotificationChannel(this)
        val services = AppServices.create(this)

        setContent {
            ProsaryTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    CompositionLocalProvider(LocalAppServices provides services) {
                        ProsaryApp()
                    }
                }
            }
        }
    }
}
