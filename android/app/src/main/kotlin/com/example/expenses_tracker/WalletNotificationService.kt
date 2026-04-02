package com.example.expenses_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import java.util.UUID
import java.util.regex.Pattern

/**
 * Listens for Google Wallet payment notifications and writes them directly to
 * Firestore as expenses — no Flutter engine needed.
 *
 * Works when the app is in the foreground, background, OR fully killed, because
 * NotificationListenerService is an independent Android service bound by the system.
 * The Flutter UI picks up the new document automatically via its existing Firestore
 * stream subscription the next time the app is opened.
 */
class WalletNotificationService : NotificationListenerService() {

    // Tracks recently-processed notification keys to prevent duplicate Firestore writes.
    // Google Wallet sometimes fires onNotificationPosted twice for a single payment
    // (e.g. initial post + bigText update). Keys are evicted after DEDUP_WINDOW_MS.
    private val recentKeys = mutableMapOf<String, Long>()
    private val DEDUP_WINDOW_MS = 15_000L // 15 seconds

    companion object {
        private const val TAG              = "WalletNotifService"
        private const val NOTIF_CHANNEL_ID = "wallet_auto_expense"
        private const val NOTIF_CHANNEL_NAME = "Wallet Auto-Expense"

        private val WALLET_PACKAGES = setOf(
            "com.google.android.apps.walletnfcrel",   // Google Wallet (NFC, most Western markets)
            "com.google.android.apps.wallet",         // Google Wallet (some regions/devices)
            "com.google.android.apps.googlepay",      // Google Pay (rebranded, some markets)
            "com.google.android.apps.nbu.paisa.user", // Google Pay (India and some Asian markets)
        )

        // Keywords matched case-insensitively → category "Groceries".
        private val GROCERY_KEYWORDS = listOf("lidl", "spar", "hofer", "mercator")

        // Ordered most-specific → least-specific; first match wins.
        private val AMOUNT_PATTERNS = listOf(
            Pattern.compile("""[\$€£₹¥₩₽]\s?([\d]+[.,]\d{2})"""),
            Pattern.compile("""лв\s?([\d]+[.,]\d{2})"""),
            Pattern.compile("""([\d]+[.,]\d{2})\s?лв"""),
            Pattern.compile("""([\d]+[.,]\d{2})\s?(USD|EUR|GBP|BGN|RON|HRK|RSD|PLN|CZK|HUF|UAH|CHF|SEK|NOK|DKK|TRY)"""),
            Pattern.compile("""(USD|EUR|GBP|BGN|RON|HRK|RSD|PLN|CZK|HUF|UAH|CHF|SEK|NOK|DKK|TRY)\s?([\d]+[.,]\d{2})"""),
            Pattern.compile("""([\d]+[.,]\d{2})"""),
        )

        private val MERCHANT_TO_PATTERN = Pattern.compile(
            """(?:paid|payment\s+to|pay\s+to)\s+(?:[\$€£₹¥₩₽]\s?[\d.,]+\s+(?:to\s+)?)?(.+?)(?:\s*[·•|]|${'$'})""",
            Pattern.CASE_INSENSITIVE,
        )
        private val MERCHANT_AT_PATTERN = Pattern.compile(
            """(?:\bat\s+)(.+?)(?:\s*[·•|]|\s+[\$€£₹¥₩₽]|${'$'})""",
            Pattern.CASE_INSENSITIVE,
        )
    }

    // ── Service lifecycle ─────────────────────────────────────────────────────

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected")
    }

    /**
     * Called when the system temporarily unbinds the service (e.g. after a
     * crash, low-memory kill, or the user toggling the permission). We
     * immediately request a rebind so the service resumes without requiring
     * the user to force-stop and reopen the app.
     */
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Notification listener disconnected — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, WalletNotificationService::class.java))
        }
    }

    // ── Notification listener ──────────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        // In debug builds, log every package so mismatches are easy to diagnose.
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "onNotificationPosted pkg=${sbn.packageName}")
        }
        if (sbn.packageName !in WALLET_PACKAGES) return

        // Deduplicate: skip if we already processed this exact notification recently.
        val now = System.currentTimeMillis()
        val lastSeen = recentKeys[sbn.key]
        if (lastSeen != null && now - lastSeen < DEDUP_WINDOW_MS) {
            Log.d(TAG, "Duplicate notification ignored: ${sbn.key}")
            return
        }
        recentKeys[sbn.key] = now
        // Prune stale entries to avoid unbounded growth.
        recentKeys.entries.removeAll { now - it.value >= DEDUP_WINDOW_MS }

        val extras  = sbn.notification?.extras ?: return
        val title   = extras.getString("android.title") ?: ""
        val text    = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val body    = if (bigText.isNotEmpty()) bigText else text

        Log.d(TAG, "pkg=${sbn.packageName} title=[$title] text=[$text] bigText=[$bigText]")

        val amount = extractAmount("$title $body")
        if (amount == null) {
            Log.w(TAG, "Could not extract amount — skipping. title=[$title] body=[$body]")
            return
        }
        val merchant = extractMerchant(title, body)
        val category = categoryForMerchant(merchant)

        Log.d(TAG, "Parsed → merchant=$merchant  amount=$amount  category=$category")

        writeExpenseToFirestore(merchant, amount, category)
    }

    // ── Categorization ────────────────────────────────────────────────────────

    private fun categoryForMerchant(merchant: String): String {
        val lower = merchant.lowercase()
        return if (GROCERY_KEYWORDS.any { lower.contains(it) }) "Groceries" else "Other"
    }

    // ── Firestore write ───────────────────────────────────────────────────────

    private fun writeExpenseToFirestore(merchant: String, amount: Double, category: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.w(TAG, "No authenticated user — expense not saved")
            return
        }

        val id = UUID.randomUUID().toString()
        val doc = hashMapOf(
            "id"       to id,
            "title"    to merchant,
            "amount"   to amount,
            "date"     to Timestamp.now(),
            "category" to category,
            "note"     to "Auto-captured from Google Wallet",
        )

        FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("expenses").document(id)
            .set(doc)
            .addOnSuccessListener {
                Log.d(TAG, "Expense saved: $merchant €$amount")
                showLocalNotification(merchant, amount, category)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Firestore write failed: $e")
            }
    }

    // ── Local notification ────────────────────────────────────────────────────

    private fun showLocalNotification(merchant: String, amount: Double, category: String) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            NOTIF_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Notifies when a Google Wallet payment is added as an expense."
        }
        manager.createNotificationChannel(channel)

        // Tapping the notification opens the app on the Expenses tab.
        val openIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(AddTransactionWidget.EXTRA_ACTION, "open_expenses")
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val amountStr = String.format("%.2f", amount)
        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Expense added from Google Wallet")
            .setContentText("$merchant — €$amountStr  ·  $category")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    // ── Parsing helpers ───────────────────────────────────────────────────────

    private fun extractAmount(text: String): Double? {
        for (pattern in AMOUNT_PATTERNS) {
            val matcher = pattern.matcher(text)
            while (matcher.find()) {
                for (g in 1..matcher.groupCount()) {
                    val raw = matcher.group(g) ?: continue
                    if (raw.all { it.isLetter() }) continue
                    val value = raw.replace(",", ".").toDoubleOrNull() ?: continue
                    if (value > 0) return value
                }
            }
        }
        return null
    }

    private fun extractMerchant(title: String, body: String): String {
        MERCHANT_TO_PATTERN.matcher(body).let { m ->
            if (m.find()) {
                val candidate = m.group(1)?.trim()
                if (!candidate.isNullOrEmpty()) return candidate
            }
        }
        MERCHANT_AT_PATTERN.matcher(body).let { m ->
            if (m.find()) {
                val candidate = m.group(1)?.trim()
                if (!candidate.isNullOrEmpty()) return candidate
            }
        }
        val firstSegment = body.split(Regex("""[·•|]""")).firstOrNull()?.trim()
        if (!firstSegment.isNullOrEmpty() && !firstSegment.contains(Regex("""[\d\$€£₹¥₩₽]"""))) {
            return firstSegment
        }
        return title
    }
}
