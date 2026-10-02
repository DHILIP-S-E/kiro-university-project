package com.awsugmdu.personal_memory_os

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home-screen widget: the day's brief (overdue, today, next deadlines).
 *
 * Flutter computes the content and hands it over as JSON ([store]); this class only
 * draws it. It also redraws on the system's 30-minute tick, marking items whose time
 * has passed since the app last updated them.
 */
class PmosWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { manager.updateAppWidget(it, render(context)) }
    }

    companion object {
        private const val PREFS = "pmos_widget"
        private const val KEY = "snapshot"

        private const val WHITE = "#F3F4F6"
        private const val OVERDUE = "#EF4444"
        private const val AMBER = "#F59E0B"

        private val ROWS = listOf(
            Triple(R.id.row1, R.id.when1, R.id.title1),
            Triple(R.id.row2, R.id.when2, R.id.title2),
            Triple(R.id.row3, R.id.when3, R.id.title3),
            Triple(R.id.row4, R.id.when4, R.id.title4),
        )

        /** Save the latest snapshot and redraw every placed widget. */
        fun store(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
            renderAll(context)
        }

        fun renderAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PmosWidgetProvider::class.java))
            ids.forEach { manager.updateAppWidget(it, render(context)) }
        }

        private fun render(context: Context, nowMillis: Long = System.currentTimeMillis()): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_pmos)

            // Tapping anywhere opens the app.
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )

            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            val snapshot = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
            if (snapshot == null) {
                views.setTextViewText(R.id.widget_headline, context.getString(R.string.widget_empty))
                ROWS.forEach { views.setViewVisibility(it.first, android.view.View.GONE) }
                return views
            }

            views.setTextViewText(R.id.widget_headline, snapshot.optString("headline"))
            val lines = snapshot.optJSONArray("lines")
            ROWS.forEachIndexed { index, (row, whenId, titleId) ->
                val line = lines?.optJSONObject(index)
                if (line == null) {
                    views.setViewVisibility(row, android.view.View.GONE)
                    return@forEachIndexed
                }
                val overdue = line.optBoolean("overdue")
                val passed = !overdue && line.optLong("atMillis") < nowMillis
                // overdue = red; passed since the last update = red too (it is now overdue);
                // upcoming deadline = amber; otherwise normal.
                val colour = when {
                    overdue || passed -> OVERDUE
                    line.optBoolean("deadline") -> AMBER
                    else -> WHITE
                }
                views.setViewVisibility(row, android.view.View.VISIBLE)
                views.setTextViewText(whenId, line.optString("when"))
                views.setTextViewText(titleId, line.optString("title"))
                views.setTextColor(titleId, Color.parseColor(colour))
            }
            return views
        }
    }
}
