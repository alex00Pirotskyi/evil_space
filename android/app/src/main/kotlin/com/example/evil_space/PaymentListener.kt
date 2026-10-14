package com.example.evil_space

import android.app.Notification
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

private const val SOURCE_PACKAGE = "com.VCB"
private const val WEBHOOK_URL = "https://evils.space/api/webhooks/vcb-device"
private const val JOB_ID = 812602
private const val SETTINGS = "evil_payment_listener"

object VcbParser {
    private val notice = Regex(
        """Số dư TK VCB\s+(\d{6,20})\s*\+\s*([\d,.]+)\s*VND\s+lúc\s+(\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2})\..*?\bRef\s+Vietcombank:\s*(\d{6,20}):(.+)$""",
        RegexOption.IGNORE_CASE
    )
    private val order = Regex("""(?:^|[^A-Z0-9])EVIL[\s._-]*([A-HJ-NP-Z2-9]{6})(?=$|[^A-Z0-9])""")

    fun parse(text: String): JSONObject? {
        val clean = text.replace(Regex("""\s+"""), " ").trim()
        val match = notice.find(clean) ?: return null
        val account = match.groupValues[1]
        if (match.groupValues[4] != account) return null
        val amount = match.groupValues[2].replace(",", "").replace(".", "").toLongOrNull()
            ?: return null
        if (amount <= 0 || amount > 10_000_000_000L) return null
        val description = match.groupValues[5].trim()
        if (description.length > 512 || order.find(description.uppercase(Locale.US)) == null) return null
        val formatter = SimpleDateFormat("dd-MM-yyyy HH:mm:ss", Locale.US).apply {
            isLenient = false
            timeZone = TimeZone.getTimeZone("Asia/Ho_Chi_Minh")
        }
        val parsedTime = formatter.parse(match.groupValues[3]) ?: return null
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Ho_Chi_Minh")
        }.format(parsedTime)
        return JSONObject().apply {
            put("source", SOURCE_PACKAGE)
            put("accountNumber", account)
            put("amountVnd", amount)
            put("description", description)
            put("transactionAt", timestamp)
        }
    }

    fun id(event: JSONObject): String {
        val canonical = event.getString("accountNumber") + "\n" +
            event.getLong("amountVnd") + "\n" + event.getString("transactionAt") + "\n" +
            event.getString("description").uppercase(Locale.US)
        val bytes = MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }
}

class VcbNotificationService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn?.packageName != SOURCE_PACKAGE) return
        val extras: Bundle = sbn.notification?.extras ?: return
        val candidates = listOfNotNull(
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.joinToString(" ")
        )
        val event = candidates.firstNotNullOfOrNull {
            try { VcbParser.parse(it) } catch (_: Exception) { null }
        }
        val store = PaymentStore(applicationContext)
        store.recordNotification()
        if (event != null) {
            if (store.enqueue(event)) {
                DeliveryScheduler.schedule(applicationContext)
                // Low-latency best effort; JobScheduler remains the durable retry path.
                DeliveryScheduler.tryImmediate(applicationContext)
            }
        } else {
            store.recordUnmatched()
        }
    }
}

class PaymentStore(context: Context) : SQLiteOpenHelper(context, "vcb_events.db", null, 1) {
    private val prefs = context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE events (" +
                "id TEXT PRIMARY KEY, payload TEXT NOT NULL, status TEXT NOT NULL, " +
                "created_at INTEGER NOT NULL)"
        )
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun recordNotification() {
        prefs.edit().putLong("last_notification", System.currentTimeMillis()).apply()
    }
    fun recordUnmatched() {
        prefs.edit().putString("last_notice", "VCB notification without a complete matching transfer reference").apply()
    }

    @Synchronized fun enqueue(event: JSONObject): Boolean {
        val values = ContentValues().apply {
            put("id", VcbParser.id(event))
            put("payload", event.toString())
            put("status", "pending")
            put("created_at", System.currentTimeMillis())
        }
        return writableDatabase.insertWithOnConflict(
            "events", null, values, SQLiteDatabase.CONFLICT_IGNORE
        ) != -1L
    }

    fun next(): Pair<String, String>? {
        readableDatabase.rawQuery(
            "SELECT id, payload FROM events WHERE status = 'pending' ORDER BY created_at ASC LIMIT 1",
            null
        ).use { cursor ->
            return if (cursor.moveToFirst()) Pair(cursor.getString(0), cursor.getString(1)) else null
        }
    }

    fun mark(id: String, status: String) {
        if (status !in setOf("matched", "already_paid", "ignored")) return
        writableDatabase.update("events", ContentValues().apply { put("status", status) },
            "id = ? AND status = 'pending'", arrayOf(id))
        prefs.edit().putLong("last_delivery", System.currentTimeMillis())
            .putString("last_error", "").apply()
        // Keep only seven days of completed event summaries on the device.
        writableDatabase.execSQL(
            "DELETE FROM events WHERE status != 'pending' AND created_at < ?",
            arrayOf(System.currentTimeMillis() - 7L * 24 * 3600 * 1000)
        )
    }

    fun error(text: String) {
        prefs.edit().putString("last_error", text.take(120)).apply()
    }
    fun connectionOk() {
        prefs.edit().putLong("last_delivery", System.currentTimeMillis())
            .putString("last_error", "").apply()
    }

    fun status(context: Context): Map<String, Any> {
        var pending = 0
        readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM events WHERE status = 'pending'", null
        ).use { cursor -> if (cursor.moveToFirst()) pending = cursor.getInt(0) }
        val recent = mutableListOf<Map<String, Any>>()
        readableDatabase.rawQuery(
            "SELECT payload, status, created_at FROM events ORDER BY created_at DESC LIMIT 12", null
        ).use { cursor ->
            while (cursor.moveToNext()) {
                try {
                    val body = JSONObject(cursor.getString(0))
                    val reference = Regex("""EVIL[\s._-]*([A-HJ-NP-Z2-9]{6})""")
                        .find(body.getString("description").uppercase(Locale.US))
                        ?.groupValues?.get(1) ?: "unknown"
                    recent.add(mapOf(
                        "amount" to body.getLong("amountVnd"),
                        "code" to reference,
                        "status" to cursor.getString(1),
                        "createdAt" to cursor.getLong(2)
                    ))
                } catch (_: Exception) { /* Ignore corrupt local entry. */ }
            }
        }
        val access = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            .orEmpty().split(':').mapNotNull { ComponentName.unflattenFromString(it) }
            .any { it.packageName == context.packageName &&
                it.className == VcbNotificationService::class.java.name }
        return mapOf(
            "notificationAccess" to access,
            "configured" to SecretVault.read(context).isNotEmpty(),
            "pending" to pending,
            "lastNotification" to prefs.getLong("last_notification", 0L),
            "lastDelivery" to prefs.getLong("last_delivery", 0L),
            "lastError" to prefs.getString("last_error", "").orEmpty(),
            "lastNotice" to prefs.getString("last_notice", "").orEmpty(),
            "recent" to recent
        )
    }
}

object SecretVault {
    private const val KEY = "evil_listener_v1"
    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(KEY, null)
        if (existing is SecretKey) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(KEY,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .build())
        return generator.generateKey()
    }
    fun save(context: Context, value: String) {
        require(value.length in 32..256) { "Use a random shared secret of 32–256 characters." }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE).edit()
            .putString("encrypted_secret", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .apply()
    }
    fun read(context: Context): String {
        val stored = context.getSharedPreferences(SETTINGS, Context.MODE_PRIVATE)
            .getString("encrypted_secret", null) ?: return ""
        return try {
            val bytes = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
        } catch (_: Exception) { "" }
    }
}

object DeliveryScheduler {
    fun tryImmediate(context: Context) {
        Thread {
            val store = PaymentStore(context)
            try {
                val event = store.next() ?: return@Thread
                val response = send(context, event.second)
                val status = response.optString("status", "")
                if (status in setOf("matched", "already_paid", "ignored")) {
                    store.mark(event.first, status)
                } else {
                    store.error("Unexpected server response")
                }
            } catch (error: Exception) {
                store.error(error.message ?: "Upload unavailable")
                schedule(context)
            }
        }.start()
    }

    fun schedule(context: Context) {
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        val info = JobInfo.Builder(JOB_ID, ComponentName(context, DeliveryJob::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setBackoffCriteria(30_000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
            .setPersisted(true).build()
        scheduler.schedule(info)
    }

    fun send(context: Context, payload: String): JSONObject {
        val secret = SecretVault.read(context)
        if (secret.isEmpty()) throw IllegalStateException("Configure the device secret first")
        val epoch = (System.currentTimeMillis() / 1000).toString()
        val mac = Mac.getInstance("HmacSHA256").apply {
            init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        }
        val signature = mac.doFinal((epoch + "\n" + payload).toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        val connection = URL(WEBHOOK_URL).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-Evil-Timestamp", epoch)
            connection.setRequestProperty("X-Evil-Signature", signature)
            connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status != 200) throw IllegalStateException("HTTP " + status)
            val result = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            if (!result.optBoolean("ok")) throw IllegalStateException("Server rejected event")
            return result
        } finally {
            connection.disconnect()
        }
    }
}

class DeliveryJob : JobService() {
    @Volatile private var running = false
    override fun onStartJob(params: JobParameters): Boolean {
        running = true
        Thread {
            var retry = false
            try {
                val store = PaymentStore(applicationContext)
                while (running) {
                    val event = store.next() ?: break
                    try {
                        val result = DeliveryScheduler.send(applicationContext, event.second)
                        val status = result.optString("status", "")
                        if (status !in setOf("matched", "already_paid", "ignored")) {
                            throw IllegalStateException("Unexpected server response")
                        }
                        store.mark(event.first, status)
                    } catch (error: Exception) {
                        store.error(error.message ?: "Network error")
                        retry = true
                        break
                    }
                }
            } catch (_: Exception) {
                retry = true
            } finally {
                if (running) jobFinished(params, retry)
            }
        }.start()
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean {
        running = false
        return true
    }
}
