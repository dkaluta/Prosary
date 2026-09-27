package com.dkaluta.prosary

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings

internal data class LauncherIconChange(val color: AppColor, val enabled: Boolean)

/** Enable the new entry first on older Android versions. The target Activity is never disabled,
 * so widget/reminder links and shortcuts created before launcher aliases still open the app. */
internal fun launcherIconChanges(selected: AppColor, enabled: Set<AppColor>): List<LauncherIconChange> =
    AppColor.entries.sortedBy { it != selected }.mapNotNull { color ->
        val desired = color == selected
        LauncherIconChange(color, desired).takeIf { desired != (color in enabled) }
    }

object LauncherIconController {
    fun select(context: Context, id: String): Boolean {
        val previous = AppColor.resolve(AppSettings.appColor)
        val selected = AppColor.resolve(id)
        return runCatching {
            apply(context, selected)
            AppSettings.setAppColor(selected.id)
        }.onFailure {
            // A failed legacy multi-call update must still leave a usable launcher entry.
            runCatching { apply(context, previous) }
        }.isSuccess
    }

    /** Reconcile restored preferences and component state on launch, without changing the
     * current Activity or resetting any prayer/window state. */
    fun synchronize(context: Context) {
        runCatching { apply(context, AppColor.resolve(AppSettings.appColor)) }
    }

    private fun apply(context: Context, selected: AppColor) {
        val manager = context.packageManager
        fun component(color: AppColor) = ComponentName(context.packageName, color.launcherClass)
        val enabled = AppColor.entries.filterTo(mutableSetOf()) { color ->
            when (manager.getComponentEnabledSetting(component(color))) {
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> color == AppColor.Blue
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                else -> false
            }
        }
        val changes = launcherIconChanges(selected, enabled)
        if (changes.isEmpty()) return
        fun state(change: LauncherIconChange) = if (change.enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        if (Build.VERSION.SDK_INT >= 33) {
            manager.setComponentEnabledSettings(changes.map { change ->
                PackageManager.ComponentEnabledSetting(component(change.color), state(change), PackageManager.DONT_KILL_APP)
            })
        } else {
            changes.forEach { change ->
                manager.setComponentEnabledSetting(component(change.color), state(change), PackageManager.DONT_KILL_APP)
            }
        }
    }
}
