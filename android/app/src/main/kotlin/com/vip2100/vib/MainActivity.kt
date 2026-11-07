package com.vip2100.vib

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var holdCallback: Runnable? = null
    private var windowAlive = true
    private val captureLock = CaptureLock(
        debuggable = BuildConfig.DEBUG,
        scheduleHold = { token, delayMs ->
            holdCallback?.let(mainHandler::removeCallbacks)
            val callback = Runnable { onCaptureHoldElapsed(token) }
            holdCallback = callback
            mainHandler.postDelayed(callback, delayMs)
        },
        cancelHold = {
            holdCallback?.let(mainHandler::removeCallbacks)
            holdCallback = null
        },
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        secureWindowAtStart()
        ensureCollectionsChannel()
    }

    override fun onDestroy() {
        windowAlive = false
        captureLock.disarm()
        super.onDestroy()
    }

    /** Release starts secure. Debug starts capturable. A new engine resets the generation. */
    private fun secureWindowAtStart() {
        captureLock.resetForNewEngine()
        captureLock.apply(null, 0L)
        publishCapture()
    }

    private fun onCaptureHoldElapsed(token: Long) {
        if (!windowAlive) return
        captureLock.onHoldElapsed(token)
        publishCapture()
    }

    private fun publishCapture() {
        if (!windowAlive) return
        ScreenCapturePolicy.push(window, captureLock.secure)
    }

    private fun ensureCollectionsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val id = getString(R.string.notification_channel_id)
        val channel = NotificationChannel(
            id,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = getString(R.string.notification_channel_description)
        channel.setShowBadge(true)
        manager.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        secureWindowAtStart()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/screen_security")
            .setMethodCallHandler { call, result ->
                val handled = CaptureMessages.handle(
                    call.method,
                    call.arguments,
                    captureLock,
                )
                publishCapture()
                when (handled.status) {
                    CaptureMessages.Status.APPLIED -> result.success(handled.applied)
                    CaptureMessages.Status.NOT_IMPLEMENTED -> result.notImplemented()
                    CaptureMessages.Status.INVALID ->
                        result.error("invalid_capture_policy", "generation required", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/android_notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/system_tray")
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(showPrivateTray(args))
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/connectivity")
            .setMethodCallHandler { call, result ->
                if (call.method == "isOnline") {
                    val manager = getSystemService(ConnectivityManager::class.java)
                    val network = manager.activeNetwork
                    val caps = network?.let { manager.getNetworkCapabilities(it) }
                    val online = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
                    result.success(online)
                } else {
                    result.notImplemented()
                }
            }
    }

    /// Private notification on `vib_collections_alerts`. The public version is
    /// generic so a locked screen does not show the employee name.
    ///
    /// The content intent uses the local-notifications plugin's
    /// `SELECT_NOTIFICATION` action and `payload` extra, so a tap still
    /// reaches that plugin on a cold start.
    private fun showPrivateTray(args: Map<*, *>): Boolean {
        val manager = NotificationManagerCompat.from(this)
        if (!manager.areNotificationsEnabled()) return false
        ensureCollectionsChannel()
        val id = (args["id"] as? Number)?.toInt() ?: return false
        val tag = args["tag"] as? String ?: return false
        val title = args["title"] as? String ?: ""
        val body = args["body"] as? String ?: ""
        val publicTitle = args["publicTitle"] as? String ?: ""
        val publicBody = args["publicBody"] as? String ?: ""
        val payload = args["payload"] as? String ?: ""
        val icon = resources.getIdentifier("ic_stat_notification", "drawable", packageName)
        if (icon == 0) return false
        val channelId = getString(R.string.notification_channel_id)
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launch.action = "SELECT_NOTIFICATION"
        launch.putExtra("payload", payload)
        launch.putExtra("notificationId", id)
        launch.putExtra("notificationTag", tag)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val pending = PendingIntent.getActivity(this, id, launch, flags)
        val publicVersion = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(icon)
            .setContentTitle(publicTitle)
            .setContentText(publicBody)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()
        return try {
            manager.notify(tag, id, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }
}
