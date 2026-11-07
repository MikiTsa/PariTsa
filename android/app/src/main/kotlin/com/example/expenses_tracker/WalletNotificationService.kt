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
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Currency
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.regex.Pattern
import kotlin.math.max
import kotlin.math.roundToLong

/**
 * Listens for Google Wallet payment notifications and writes them directly to
 * Firestore as expenses — no Flutter engine needed.
 *
 * Works when the app is in the foreground, background, OR fully killed, because
 * NotificationListenerService is an independent Android service bound by the system.
 * The Flutter UI picks up the new document automatically via its existing Firestore
 * stream subscription the next time the app is opened.
 *
 * Payments in another currency are converted to the user's default currency
 * (read from the Flutter settings). The rate comes from a live fetch, or from
 * the table the Flutter app caches when offline — in which case the entry is
 * marked rateEstimated and the app re-converts it once online.
 */
class WalletNotificationService : NotificationListenerService() {

    // Tracks recently-processed notification keys to prevent duplicate Firestore writes.
    // Google Wallet sometimes fires onNotificationPosted twice for a single payment
    // (e.g. initial post + bigText update). Keys are evicted after DEDUP_WINDOW_MS.
    private val recentKeys = mutableMapOf<String, Long>()
    private val DEDUP_WINDOW_MS = 15_000L // 15 seconds

    // Network (exchange rates) must not run on the main thread.
    private val executor = Executors.newSingleThreadExecutor()

    companion object {
        private const val TAG              = "WalletNotifService"
        private const val NOTIF_CHANNEL_ID = "wallet_auto_expense"
        private const val NOTIF_CHANNEL_NAME = "Wallet Auto-Expense"

        // Shared with Flutter's shared_preferences (legacy API) — keys get a "flutter." prefix.
        private const val FLUTTER_PREFS     = "FlutterSharedPreferences"
        private const val KEY_BASE_CURRENCY = "flutter.settings_currency"
        private const val KEY_RATES_PREFIX  = "flutter.fx_latest_"

        // In debug builds, also accept our own package so the test button in
        // HomeScreen can fire a real notification that goes through this exact
        // pipeline — proving the service is alive without needing a real payment.
        private val WALLET_PACKAGES: Set<String> = buildSet {
            add("com.google.android.apps.walletnfcrel")   // Google Wallet (NFC, most Western markets)
            add("com.google.android.apps.wallet")         // Google Wallet (some regions/devices)
            add("com.google.android.apps.googlepay")      // Google Pay (rebranded, some markets)
            add("com.google.android.apps.nbu.paisa.user") // Google Pay (India and some Asian markets)
            if (BuildConfig.DEBUG) add("com.example.expenses_tracker")
        }

        // Notifications where no money moved — skip entirely.
        // Bare "pending" is deliberately excluded: a completed tap can still be
        // reported as pending settlement, and silently dropping a real payment
        // is worse than an occasional extra entry the user can delete.
        private val DECLINED_KEYWORDS = listOf(
            "declined", "failed", "could not complete", "unsuccessful",
            "not successful", "authorization hold",
        )

        // Notifications where money was returned to the user — add as income.
        private val REFUND_KEYWORDS = listOf(
            "refund", "refunded", "reversed", "reversal", "voided", "void",
            "chargeback", "money back",
        )

        // Refunds land in incomes, so they use a category from the default
        // income list rather than the merchant-based expense category.
        private const val REFUND_CATEGORY = "Other"

        // Keywords matched case-insensitively → category "Groceries".
        private val GROCERY_KEYWORDS = listOf("lidl", "spar", "hofer", "mercator")

        // An amount with optional thousands separators: 52.43, 5,529.00, 5.529,00, 1 234,50, 300.
        private const val NUM =
            """\d{1,3}(?:[.,  ' ]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?"""

        // Currency symbols, longest first so "CA$" wins over "$".
        private const val SYM =
            """US\$|CA\$|AU\$|NZ\$|HK\$|MX\$|R\$|A\$|C\$|S\$|€|£|¥|₹|₩|₽|₺|₴|₪|₫|฿|₱|₦|₸|₼|₾|\$|zł|Kč|Ft|kr|lei|лв\.?|ден\.?|дин\.?|din\.?|Fr\.?"""

        // "MKD5,529.00", "€52.43", "ден 300,00"
        private val PREFIX_PATTERN =
            Pattern.compile("""(?<![A-Za-z])([A-Z]{3}|$SYM)\s?($NUM)""")

        // "52.43 EUR", "300,00 ден"
        private val SUFFIX_PATTERN =
            Pattern.compile("""($NUM)\s?([A-Z]{3}(?![A-Za-z])|$SYM)""")

        // Last resort: a number with cents and no currency marker.
        private val BARE_PATTERN =
            Pattern.compile("""(\d{1,3}(?:[.,]\d{3})+[.,]\d{2}|\d+[.,]\d{2})""")

        // "$", "kr" and "¥" are shared — prefer the default currency if it uses them.
        private val DOLLAR_CURRENCIES = setOf(
            "USD", "CAD", "AUD", "NZD", "HKD", "SGD", "MXN", "ARS", "CLP", "COP",
            "TWD", "JMD", "BBD", "BSD", "BZD", "FJD", "GYD", "LRD", "NAD", "SBD",
            "SRD", "TTD", "XCD", "BMD", "KYD", "BND",
        )
        private val KRONA_CURRENCIES = setOf("SEK", "NOK", "DKK", "ISK")

        private val MERCHANT_TO_PATTERN = Pattern.compile(
            """(?:paid|payment\s+to|pay\s+to)\s+(?:[\$€£₹¥₩₽]\s?[\d.,]+\s+(?:to\s+)?)?(.+?)(?:\s*[·•|]|${'$'})""",
            Pattern.CASE_INSENSITIVE,
        )
        private val MERCHANT_AT_PATTERN = Pattern.compile(
            """(?:\bat\s+)(.+?)(?:\s*[·•|]|\s+[\$€£₹¥₩₽]|${'$'})""",
            Pattern.CASE_INSENSITIVE,
        )
    }

    private data class Payment(val amount: Double, val currency: String?)
    private data class Rate(val value: Double, val estimated: Boolean)

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

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    // ── Notification listener ──────────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        // In debug builds, log every package so mismatches are easy to diagnose.
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "onNotificationPosted pkg=${sbn.packageName}")
        }
        if (sbn.packageName !in WALLET_PACKAGES) return

        // Guard against a feedback loop in debug mode: our package is in
        // WALLET_PACKAGES so the service would otherwise re-process its own
        // confirmation notifications endlessly. Only allow our own
        // "wallet_test_trigger" channel through; ignore everything else we post.
        if (sbn.packageName == packageName) {
            val channelId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                sbn.notification?.channelId else null
            if (channelId != "wallet_test_trigger") return
        }

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

        val base = baseCurrency()
        val payment = extractPayment(title, body, base)

        if (payment == null) {
            Log.w(TAG, "Could not extract amount — skipping. title=[$title] body=[$body]")
            return
        }

        if (isDeclinedNotification(title, body)) {
            Log.d(TAG, "Declined/failed notification — skipping. title=[$title]")
            return
        }

        // null = paid in the default currency, nothing to convert.
        val foreignCurrency = payment.currency?.takeIf { it != base }
        val merchant = cleanMerchant(extractMerchant(title, body), payment.currency)
        val isRefund = isRefundNotification(title, body)
        val category = if (isRefund) REFUND_CATEGORY else categoryForMerchant(merchant)

        Log.d(TAG, "Parsed → merchant=$merchant  amount=${payment.amount}  " +
            "currency=${payment.currency ?: "(default)"}  base=$base  category=$category  isRefund=$isRefund")

        executor.execute {
            val rate = foreignCurrency?.let { rateFor(it, base) }
            writeToFirestore(merchant, payment.amount, foreignCurrency, rate, category, isRefund, base)
        }
    }

    // ── Notification classification ───────────────────────────────────────────

    /** Returns true if no money actually moved (decline, fail, authorization hold). */
    private fun isDeclinedNotification(title: String, body: String): Boolean {
        val combined = "$title $body".lowercase()
        return DECLINED_KEYWORDS.any { combined.contains(it) }
    }

    /** Returns true if money was returned to the user (refund, reversal, void). */
    private fun isRefundNotification(title: String, body: String): Boolean {
        val combined = "$title $body".lowercase()
        return REFUND_KEYWORDS.any { combined.contains(it) }
    }

    // ── Categorization ────────────────────────────────────────────────────────

    private fun categoryForMerchant(merchant: String): String {
        val lower = merchant.lowercase()
        return if (GROCERY_KEYWORDS.any { lower.contains(it) }) "Groceries" else "Other"
    }

    // ── Currency ──────────────────────────────────────────────────────────────

    private fun flutterPrefs() = getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)

    /** The user's default currency, as set in the app's Settings. */
    private fun baseCurrency(): String =
        flutterPrefs().getString(KEY_BASE_CURRENCY, null)?.uppercase() ?: "EUR"

    private fun isIsoCurrency(code: String): Boolean = try {
        Currency.getInstance(code)
        true
    } catch (e: IllegalArgumentException) {
        false
    }

    /** Maps a code or symbol from the notification to an ISO code, or null. */
    private fun resolveCurrency(token: String, base: String): String? {
        val t = token.trimEnd('.')
        if (t.length == 3 && t.all { it in 'A'..'Z' }) {
            return if (isIsoCurrency(t)) t else null
        }
        return when (t) {
            "€" -> "EUR"
            "£" -> "GBP"
            "₹" -> "INR"
            "₩" -> "KRW"
            "₽" -> "RUB"
            "₺" -> "TRY"
            "₴" -> "UAH"
            "₪" -> "ILS"
            "₫" -> "VND"
            "฿" -> "THB"
            "₱" -> "PHP"
            "₦" -> "NGN"
            "₸" -> "KZT"
            "₼" -> "AZN"
            "₾" -> "GEL"
            "zł" -> "PLN"
            "Kč" -> "CZK"
            "Ft" -> "HUF"
            "lei" -> "RON"
            "лв" -> "BGN"
            "ден" -> "MKD"
            "дин", "din" -> "RSD"
            "Fr" -> "CHF"
            "US\$" -> "USD"
            "CA\$", "C\$" -> "CAD"
            "AU\$", "A\$" -> "AUD"
            "NZ\$" -> "NZD"
            "HK\$" -> "HKD"
            "MX\$" -> "MXN"
            "R\$" -> "BRL"
            "S\$" -> "SGD"
            "\$" -> if (base in DOLLAR_CURRENCIES) base else "USD"
            "¥" -> if (base == "JPY" || base == "CNY") base else "JPY"
            "kr" -> if (base in KRONA_CURRENCIES) base else "SEK"
            else -> null
        }
    }

    /**
     * Parses "5,529.00", "5.529,00", "1 234,50", "300,00" or "52.43".
     * The last separator is the decimal point when it is followed by 1–2
     * digits (or both "." and "," appear); otherwise separators group thousands.
     */
    private fun parseNumber(raw: String): Double? {
        val s = raw.replace(Regex("""[\s  ']"""), "")
        val lastDot = s.lastIndexOf('.')
        val lastComma = s.lastIndexOf(',')
        val sepIndex = max(lastDot, lastComma)
        if (sepIndex < 0) return s.toDoubleOrNull()

        val sep = s[sepIndex]
        val digitsAfter = s.length - sepIndex - 1
        val bothKinds = lastDot >= 0 && lastComma >= 0
        val isDecimal = bothKinds || (s.count { it == sep } == 1 && digitsAfter in 1..2)

        return if (isDecimal) {
            val whole = s.substring(0, sepIndex).replace(".", "").replace(",", "")
            "$whole.${s.substring(sepIndex + 1)}".toDoubleOrNull()
        } else {
            s.replace(".", "").replace(",", "").toDoubleOrNull()
        }
    }

    /** Amount + currency from the body first, then the title. */
    private fun extractPayment(title: String, body: String, base: String): Payment? {
        for (text in listOf(body, title)) {
            for ((pattern, currencyFirst) in listOf(PREFIX_PATTERN to true, SUFFIX_PATTERN to false)) {
                val m = pattern.matcher(text)
                while (m.find()) {
                    val currencyToken = if (currencyFirst) m.group(1) else m.group(2)
                    val numberToken = if (currencyFirst) m.group(2) else m.group(1)
                    val currency = resolveCurrency(currencyToken ?: continue, base) ?: continue
                    val amount = parseNumber(numberToken ?: continue) ?: continue
                    if (amount > 0) return Payment(amount, currency)
                }
            }
        }
        // No currency marker: assume the default currency.
        for (text in listOf(body, title)) {
            val m = BARE_PATTERN.matcher(text)
            while (m.find()) {
                val amount = parseNumber(m.group(1) ?: continue) ?: continue
                if (amount > 0) return Payment(amount, null)
            }
        }
        return null
    }

    /** Units of [currency] per 1 [base]: live if possible, else the cached table. */
    private fun rateFor(currency: String, base: String): Rate? {
        val b = base.lowercase()
        val c = currency.lowercase()

        val live = fetchLatestRates(b)
        if (live != null) {
            storeRates(b, live.first, live.second)
            val r = live.second.optDouble(c)
            return if (!r.isNaN() && r > 0) Rate(r, estimated = false) else null
        }

        val cached = cachedRates(b) ?: return null
        val r = cached.optDouble(c)
        return if (!r.isNaN() && r > 0) Rate(r, estimated = true) else null
    }

    /** (date, rates) for [base] from the same sources the Flutter app uses. */
    private fun fetchLatestRates(base: String): Pair<String, JSONObject>? {
        val urls = listOf(
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/$base.min.json",
            "https://latest.currency-api.pages.dev/v1/currencies/$base.min.json",
        )
        for (url in urls) {
            val json = httpGetJson(url) ?: continue
            val rates = json.optJSONObject(base) ?: continue
            return json.optString("date", "") to rates
        }

        val er = httpGetJson("https://open.er-api.com/v6/latest/${base.uppercase()}")
        val upper = er?.optJSONObject("rates")
        if (er?.optString("result") == "success" && upper != null) {
            val lower = JSONObject()
            upper.keys().forEach { k -> lower.put(k.lowercase(), upper.getDouble(k)) }
            return "" to lower
        }
        return null
    }

    private fun httpGetJson(url: String): JSONObject? = try {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 5_000
            readTimeout = 5_000
        }
        try {
            if (conn.responseCode == 200) {
                JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            } else {
                null
            }
        } finally {
            conn.disconnect()
        }
    } catch (e: Exception) {
        Log.w(TAG, "Rate fetch failed: $url — $e")
        null
    }

    /** Same format the Flutter ExchangeRateService writes: {"date", "rates"}. */
    private fun storeRates(base: String, date: String, rates: JSONObject) {
        val payload = JSONObject().put("date", date).put("rates", rates)
        flutterPrefs().edit().putString(KEY_RATES_PREFIX + base, payload.toString()).apply()
    }

    private fun cachedRates(base: String): JSONObject? = try {
        flutterPrefs().getString(KEY_RATES_PREFIX + base, null)
            ?.let { JSONObject(it).optJSONObject("rates") }
    } catch (e: Exception) {
        null
    }

    private fun roundMoney(value: Double): Double =
        max(0.01, (value * 100).roundToLong() / 100.0)

    private fun formatMoney(value: Double): String = String.format(Locale.US, "%,.2f", value)

    private fun symbolFor(code: String): String = try {
        Currency.getInstance(code).getSymbol(Locale.getDefault())
    } catch (e: Exception) {
        code
    }

    // ── Firestore write ───────────────────────────────────────────────────────

    private fun writeToFirestore(
        merchant: String,
        paidAmount: Double,
        foreignCurrency: String?,
        rate: Rate?,
        category: String,
        isRefund: Boolean,
        base: String,
    ) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.w(TAG, "No authenticated user — transaction not saved")
            return
        }

        val id = UUID.randomUUID().toString()
        val doc = hashMapOf<String, Any>(
            "id"       to id,
            "title"    to merchant,
            "date"     to Timestamp.now(),
            "category" to category,
            "note"     to if (isRefund) "Auto-captured refund from Google Wallet"
                          else "Auto-captured from Google Wallet",
        )

        val amount: Double
        if (foreignCurrency == null) {
            amount = paidAmount
        } else {
            doc["originalAmount"] = paidAmount
            doc["originalCurrency"] = foreignCurrency
            if (rate != null) {
                amount = roundMoney(paidAmount / rate.value)
                doc["exchangeRate"] = rate.value
                if (rate.estimated) doc["rateEstimated"] = true
            } else {
                // No rate at all (offline, nothing cached): keep the paid amount
                // as a placeholder; the app converts it once it is online.
                amount = paidAmount
                doc["rateEstimated"] = true
            }
        }
        doc["amount"] = amount

        val collection = if (isRefund) "incomes" else "expenses"
        FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection(collection).document(id)
            .set(doc)
            .addOnSuccessListener {
                Log.d(TAG, "Saved to $collection: $merchant $amount $base " +
                    "(paid ${foreignCurrency ?: base} $paidAmount, rate=${rate?.value})")
                val shown = "${symbolFor(base)}${formatMoney(amount)}" +
                    (foreignCurrency?.let { " ($it ${formatMoney(paidAmount)})" } ?: "")
                showLocalNotification(merchant, shown, category, isRefund)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Firestore write failed: $e")
            }
    }

    // ── Local notification ────────────────────────────────────────────────────

    private fun showLocalNotification(
        merchant: String,
        amountText: String,
        category: String,
        isRefund: Boolean,
    ) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            NOTIF_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Notifies when a Google Wallet payment is captured automatically."
        }
        manager.createNotificationChannel(channel)

        // Tapping the notification opens the app on the appropriate tab.
        val tabAction = if (isRefund) "open_incomes" else "open_expenses"
        val openIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(AddTransactionWidget.EXTRA_ACTION, tabAction)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = if (isRefund) "Refund added from Google Wallet" else "Expense added from Google Wallet"
        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("$merchant — $amountText  ·  $category")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    // ── Parsing helpers ───────────────────────────────────────────────────────

    /** Wallet titles can end with the currency code ("WIZZ AIR HUNGARY MKD"). */
    private fun cleanMerchant(merchant: String, currency: String?): String {
        if (currency == null) return merchant
        val suffix = " $currency"
        return if (merchant.endsWith(suffix) && merchant.length > suffix.length) {
            merchant.removeSuffix(suffix).trim()
        } else {
            merchant
        }
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
