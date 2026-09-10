package com.dkaluta.prosary.widgets

import android.content.Context
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.MultiDayRun
import com.dkaluta.prosary.models.MultiDayRuns
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.services.AppServices

internal object SavedPrayerWidgetStore {
    private fun preferences(context: Context) = context.getSharedPreferences("prosary_widgets", Context.MODE_PRIVATE)
    fun selectedId(context: Context, widgetId: Int): String? = preferences(context).getString("prayer:$widgetId", null)
    fun select(context: Context, widgetId: Int, prayerId: String) {
        // Configuration must survive immediately after the launcher dismisses the activity.
        check(preferences(context).edit().putString("prayer:$widgetId", prayerId).commit())
    }
    fun remove(context: Context, widgetId: Int) {
        preferences(context).edit().remove("prayer:$widgetId").apply()
    }
    fun restore(context: Context, oldIds: IntArray, newIds: IntArray) {
        val selected = oldIds.map { selectedId(context, it) }
        val editor = preferences(context).edit()
        oldIds.forEach { editor.remove("prayer:$it") }
        newIds.zip(selected).forEach { (id, prayer) -> prayer?.let { editor.putString("prayer:$id", it) } }
        editor.apply()
    }

    fun progress(context: Context, services: AppServices, prayer: Prayer): WidgetProgress? {
        if (prayer.kind == PrayerKind.JesusPrayer) {
            val target = prayer.jesusPrayer.target
            val checkpoint = PrayerRunProgressStore.progress(context, PrayerRunKeys.jesus(prayer.id, target))
            return WidgetProgress.validated(checkpoint, (target as? JesusPrayerTarget.Count)?.value ?: Int.MAX_VALUE,
                PrayerRunSignatures.jesus(target), false, unbounded = target == JesusPrayerTarget.Unbounded)
        }
        if (prayer.kind == PrayerKind.Rosary) {
            val checkpoint = PrayerRunProgressStore.progress(context, PrayerRunKeys.rosary(prayer.id)) ?: return null
            return WidgetProgress.validated(checkpoint,
                services.engine.buildSteps(prayer.copy(languageCode = checkpoint.languageCode)).size,
                PrayerRunSignatures.rosary(prayer.rosary), true)
        }
        val devotionId = prayer.customDevotionId ?: return null
        val definition = PrayerPackStore.definition(devotionId) ?: return null
        val days = definition.days.orEmpty()
        var day = prayer.dayIndex ?: 0
        if (days.size > 1 && (definition.dayProgression ?: "series") == "series") {
            val run = MultiDayRuns.run(context, devotionId)
            day = when (val choice = run?.resumption(days.size) ?: MultiDayRun.Resumption.Start) {
                MultiDayRun.Resumption.Start -> 0
                is MultiDayRun.Resumption.Resume -> choice.day
                // The app must first ask which missed day to pray; do not promise a checkpoint.
                is MultiDayRun.Resumption.Choose -> return null
                MultiDayRun.Resumption.Complete -> days.lastIndex
            }
            if (run?.hasPrayedToday() == true) day = run.prayedDays.lastOrNull() ?: day
        }
        val checkpoint = PrayerRunProgressStore.progress(context, PrayerRunKeys.custom(devotionId, prayer.variantId, day)) ?: return null
        val language = PrayerPackStore.effectiveLanguage(devotionId, checkpoint.languageCode)
        val signature = PrayerRunSignatures.custom(devotionId,
            definition.effectiveVariantId(prayer.variantId, language), day, prayer.customOptions)
        return WidgetProgress.validated(checkpoint,
            services.engine.buildSteps(prayer.copy(languageCode = checkpoint.languageCode, dayIndex = day)).size,
            signature, false)
    }
}
