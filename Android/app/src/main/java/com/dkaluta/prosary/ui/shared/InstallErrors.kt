package com.dkaluta.prosary.ui.shared

import android.content.Context
import androidx.annotation.StringRes
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.repository.RepositoryClient

/** App-language text for a bundle install/import failure — typed exceptions carry string
 * resources; anything else falls back to its own (English) message, then to [fallbackRes]. */
fun installErrorMessage(
    context: Context,
    error: Throwable,
    @StringRes fallbackRes: Int = R.string.browse_install_error_generic,
): String = when (error) {
    is PrayerPackStore.InstallException ->
        error.formatArg?.let { context.getString(error.messageRes, it) }
            ?: context.getString(error.messageRes)
    is RepositoryClient.UnsupportedCatalogException -> context.getString(R.string.browse_unsupported_catalog)
    else -> error.message ?: context.getString(fallbackRes)
}
