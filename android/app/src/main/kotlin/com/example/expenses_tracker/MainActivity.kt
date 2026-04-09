package com.example.expenses_tracker

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
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
                    "isPermissionGranted" -> {
                        val granted = isNotificationListenerEnabled()
                        // If permission is granted, ensure the service is actually bound.
                        // Android does not auto-bind a NotificationListenerService after the
                        // user grants access — requestRebind() is required. Without it the
                        // service sits in the enabled list but never receives notifications
                        // until the user force-stops and reopens the app.
                        if (granted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            NotificationListenerService.requestRebind(
                                ComponentName(applicationContext, WalletNotificationService::class.java)
                            )
                        }
                        result.success(granted)
                    }
                    "openPermissionSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    // Debug-only: posts a real notification from this app that the
                    // WalletNotificationService will intercept (our package is in
                    // WALLET_PACKAGES in debug builds). This tests the full Kotlin
                    // pipeline without needing a real Google Wallet payment.
                    "testWalletNotification" -> {
                        if (BuildConfig.DEBUG) postTestWalletNotification()
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

    // Re-bind the wallet notification listener on every resume so the service
    // reconnects after being killed, after permission is re-granted, or after
    // the app is updated with new libraries.
    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isNotificationListenerEnabled()) {
            NotificationListenerService.requestRebind(
                ComponentName(applicationContext, WalletNotificationService::class.java)
            )
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

    private fun postTestWalletNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        val channelId = "wallet_test_trigger"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                android.app.NotificationChannel(
                    channelId, "Wallet Pipeline Test",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
        }
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = android.app.PendingIntent.getActivity(
            this, 0, openIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Google Pay")
            .setContentText("You paid \u20ac52.43 at Lidl")
            .setStyle(
                androidx.core.app.NotificationCompat.BigTextStyle()
                    .bigText("You paid \u20ac52.43 at Lidl \u00b7 Groceries")
            )
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        nm.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }
}
