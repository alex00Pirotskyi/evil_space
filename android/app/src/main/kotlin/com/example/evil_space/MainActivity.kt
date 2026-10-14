package com.example.evil_space

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "evils.space/payments")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> {
                        try { result.success(PaymentStore(applicationContext).status(applicationContext)) }
                        catch (error: Exception) { result.error("status", error.message, null) }
                    }
                    "configure" -> {
                        try {
                            SecretVault.save(applicationContext, call.argument<String>("secret").orEmpty())
                            DeliveryScheduler.schedule(applicationContext)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("configuration", error.message, null)
                        }
                    }
                    "notificationSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(true)
                    }
                    "batterySettings" -> {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        result.success(true)
                    }
                    "flush" -> {
                        DeliveryScheduler.schedule(applicationContext)
                        result.success(true)
                    }
                    "ping" -> {
                        Thread {
                            try {
                                val data = DeliveryScheduler.send(applicationContext,
                                    JSONObject().put("type", "ping").toString())
                                PaymentStore(applicationContext).connectionOk()
                                runOnUiThread { result.success(data.optString("type") == "pong") }
                            } catch (error: Exception) {
                                PaymentStore(applicationContext).error(error.message ?: "Connection failed")
                                runOnUiThread { result.error("connection", error.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
