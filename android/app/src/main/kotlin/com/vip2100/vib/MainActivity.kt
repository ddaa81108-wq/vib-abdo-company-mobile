package com.vip2100.vib

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        ensureCollectionsChannel()
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
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/screen_security")
            .setMethodCallHandler { call, result ->
                if (call.method == "enable") {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE,
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
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
