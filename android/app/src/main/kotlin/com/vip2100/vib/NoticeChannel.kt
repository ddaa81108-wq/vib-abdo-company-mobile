package com.vip2100.vib

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/** Creates the audible channel before any activity or Firebase message. */
object NoticeChannel {
    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            context.getString(R.string.notification_channel_id),
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = context.getString(R.string.notification_channel_description)
        channel.setShowBadge(true)
        channel.setSound(
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        channel.enableVibration(true)
        manager.createNotificationChannel(channel)
    }
}

/** Process start. A killed-app FCM notification uses the channel without Dart. */
class VibApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        NoticeChannel.ensure(this)
    }
}
