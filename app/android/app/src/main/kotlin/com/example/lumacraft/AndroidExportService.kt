package com.example.lumacraft

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

internal class AndroidExportService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var total = 0
    private var completed = 0
    private var cancelling = false
    private var mediaProcessing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "cancel") {
            cancelling = true
            onCancel?.invoke()
            update(completed, total)
            return START_NOT_STICKY
        }
        total = intent?.getIntExtra("total", 0) ?: 0
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(
            NotificationChannel(channelId, "照片导出", NotificationManager.IMPORTANCE_LOW))
        try {
            mediaProcessing = Build.VERSION.SDK_INT >= 35
            val type = if (mediaProcessing) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
                else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            startForeground(notificationId, notification(), type)
            active = this
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LumaCraft:Export")
                .apply { acquire(6 * 60 * 60 * 1000L) }
            onStarted?.invoke(null)
        } catch (error: Exception) {
            onStarted?.invoke(error)
            stopSelf()
        } finally {
            onStarted = null
        }
        return START_NOT_STICKY
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, AndroidExportService::class.java).setAction("cancel"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("LumaCraft 正在导出")
            .setContentText(if (cancelling) "正在取消…" else "$completed / $total 张")
            .setProgress(total, completed, total == 0)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setContentIntent(open)
        if (!cancelling) builder.addAction(Notification.Action.Builder(
            null, "取消导出", stop).build())
        return builder.build()
    }

    fun update(completed: Int, total: Int) {
        this.completed = completed
        this.total = total
        getSystemService(NotificationManager::class.java).notify(notificationId, notification())
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        onCancel?.invoke()
        stopSelf()
    }

    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        if (active === this) active = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        private const val channelId = "lumacraft_export"
        private const val notificationId = 6300
        var active: AndroidExportService? = null
            private set
        var onCancel: (() -> Unit)? = null
        var onStarted: ((Exception?) -> Unit)? = null
    }
}
