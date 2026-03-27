package com.example.expenses_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews

abstract class AddTransactionWidget : AppWidgetProvider() {

    abstract val layoutId: Int
    abstract val action: String
    abstract val requestCode: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateWidget(context, appWidgetManager, appWidgetId, options)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle,
    ) {
        val views = RemoteViews(context.packageName, layoutId)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_ACTION, action)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val widthDp   = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 64)
            val heightDp  = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 64)
            val diameterDp = minOf(widthDp, heightDp).toFloat()
            views.setViewLayoutWidth(R.id.widget_circle, diameterDp, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.widget_circle, diameterDp, TypedValue.COMPLEX_UNIT_DIP)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        const val EXTRA_ACTION       = "widget_action"
        const val ACTION_ADD_EXPENSE = "add_expense"
        const val ACTION_ADD_INCOME  = "add_income"
        const val ACTION_ADD_SAVING  = "add_saving"
    }
}
