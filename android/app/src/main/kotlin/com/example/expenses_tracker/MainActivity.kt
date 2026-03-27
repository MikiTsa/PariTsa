package com.example.expenses_tracker

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val WALLET_CHANNEL = "com.example.expenses_tracker/wallet_permission"
        private const val WIDGET_CHANNEL = "com.example.expenses_tracker/widget"
    }

    private var widgetChannel: MethodChannel? = null

    // Action string from the widget that cold-started the app; cleared after Flutter reads it.
    private var pendingWidgetAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing wallet-permission channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WALLET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isNotificationListenerEnabled())
                    "openPermissionSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Widget channel.
        // Flutter calls "checkLaunchAction" once on startup (cold-launch path).
        // When the app is already running, onNewIntent pushes "openTransaction" instead.
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        )
        widgetChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLaunchAction" -> {
                    result.success(pendingWidgetAction)
                    pendingWidgetAction = null
                }
                else -> result.notImplemented()
            }
        }

        // Capture widget action present in the intent that cold-started this activity.
        pendingWidgetAction = intent?.getStringExtra(AddTransactionWidget.EXTRA_ACTION)
    }

    // Called when the activity is already running (singleTop) and a new intent arrives.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.getStringExtra(AddTransactionWidget.EXTRA_ACTION)
        if (action != null) {
            widgetChannel?.invokeMethod("openTransaction", action)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }
}
