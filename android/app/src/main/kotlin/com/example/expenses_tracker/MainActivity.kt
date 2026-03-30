package com.example.expenses_tracker

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val WALLET_CHANNEL = "com.example.expenses_tracker/wallet_permission"
        private const val WIDGET_CHANNEL  = "com.example.expenses_tracker/widget"

        // Stores the pending widget action so Flutter can read it reliably via
        // checkLaunchAction. Set in onCreate (cold start) and onNewIntent (warm
        // resume) — both fire before any Flutter lifecycle callbacks, so there
        // is no timing race.
        @Volatile var pendingWidgetAction: String? = null
    }

    // Cold-start path: capture the action before super.onCreate so it is already
    // stored when Flutter eventually calls checkLaunchAction.
    override fun onCreate(savedInstanceState: Bundle?) {
        intent?.getStringExtra(AddTransactionWidget.EXTRA_ACTION)?.let {
            pendingWidgetAction = it
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // Flutter polls this on cold launch and on every resume via checkLaunchAction.
        // The value is stored in pendingWidgetAction (set in onCreate / onNewIntent)
        // so it is always available when Flutter asks, regardless of timing.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkLaunchAction" -> {
                        val action = pendingWidgetAction
                        pendingWidgetAction = null   // consume once
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Warm-resume path: the activity is already running; Android calls onNewIntent
    // BEFORE onResume, so by the time Flutter fires AppLifecycleState.resumed the
    // action is already stored and checkLaunchAction will find it.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(AddTransactionWidget.EXTRA_ACTION)?.let {
            pendingWidgetAction = it
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }
}
