package com.sunrise.alarm.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.sunrise.alarm.MainActivity
import com.sunrise.alarm.R
import com.sunrise.alarm.util.AlarmScheduler

/**
 * 闹钟响铃前台服务
 * 负责播放铃声、振动、显示全屏通知
 */
class AlarmRingService : Service() {

    private var alarmId: Long = -1
    private var label: String = "闹钟"
    private var vibrate: Boolean = true
    private var soundUri: String = ""

    private val handler = Handler(Looper.getMainLooper())
    private var autoDismissRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRinging()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                snooze()
                stopRinging()
                stopSelf()
                return START_NOT_STICKY
            }
        }

        alarmId = intent?.getLongExtra(AlarmScheduler.EXTRA_ALARM_ID, -1) ?: -1
        label = intent?.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: "闹钟"
        vibrate = intent?.getBooleanExtra(AlarmScheduler.EXTRA_VIBRATE, true) ?: true
        soundUri = intent?.getStringExtra(AlarmScheduler.EXTRA_SOUND_URI) ?: ""

        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }

        // 获取 WakeLock 防止设备在响铃期间休眠
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SunriseAlarm:Ringing"
        )
        wakeLock?.acquire(15 * 60 * 1000L) // 最长 15 分钟

        startRinging()

        // 15分钟后自动关闭
        autoDismissRunnable = Runnable {
            stopRinging()
            stopSelf()
        }
        handler.postDelayed(autoDismissRunnable!!, 15 * 60 * 1000L)

        return START_NOT_STICKY
    }

    private fun startRinging() {
        playSound()
        if (vibrate) startVibration()
    }

    private fun stopRinging() {
        stopSound()
        stopVibration()
        autoDismissRunnable?.let { handler.removeCallbacks(it) }
    }

    // ---- 铃声 ----
    private var ringtone: android.media.Ringtone? = null
    private var mediaPlayer: android.media.MediaPlayer? = null

    private fun playSound() {
        try {
            val uri = if (soundUri.isNotEmpty()) {
                Uri.parse(soundUri)
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            }

            // 判断是否是系统铃声 URI
            val isSystemRingtone = uri.toString().startsWith("content://settings/") ||
                    uri.toString().startsWith("content://media/")

            if (isSystemRingtone) {
                // 系统铃声用 Ringtone 播放
                ringtone = RingtoneManager.getRingtone(this, uri)
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                ringtone?.play()
            } else {
                // 本地音乐用 MediaPlayer 播放（支持循环、更多格式）
                mediaPlayer = android.media.MediaPlayer().apply {
                    setDataSource(this@AlarmRingService, uri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "播放铃声失败", e)
            // 降级到默认闹钟铃声
            try {
                val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ringtone = RingtoneManager.getRingtone(this, defaultUri)
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                ringtone?.play()
            } catch (e2: Exception) {
                Log.e(TAG, "降级播放也失败", e2)
            }
        }
    }

    private fun stopSound() {
        ringtone?.stop()
        ringtone = null
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (e: Exception) {
                Log.e(TAG, "停止 MediaPlayer 失败", e)
            }
        }
        mediaPlayer = null
    }

    // ---- 振动 ----
    private var vibrator: Vibrator? = null
    private val vibrationPattern = longArrayOf(0, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 1000)
    private val vibrationAmplitudes = intArrayOf(0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255)

    private fun startVibration() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VibratorManager::class.java)
                vibrator = vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(vibrationPattern, vibrationAmplitudes, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(vibrationPattern, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "振动失败", e)
        }
    }

    private fun stopVibration() {
        vibrator?.cancel()
    }

    // ---- 稍后提醒 ----
    private fun snooze() {
        val scheduler = AlarmScheduler(this)
        val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmScheduler.ACTION_ALARM_TRIGGER
            putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmScheduler.EXTRA_LABEL, label)
            putExtra(AlarmScheduler.EXTRA_VIBRATE, vibrate)
            putExtra(AlarmScheduler.EXTRA_SOUND_URI, soundUri)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, -(alarmId + 1).toInt(), snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val triggerTime = System.currentTimeMillis() + 5 * 60 * 1000L
        val am = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
        try {
            am.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
        Log.i(TAG, "稍后提醒已设置: 5分钟后")
    }

    // ---- 通知 ----
    private fun buildNotification(): Notification {
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val contentPI = PendingIntent.getActivity(
            this, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmScheduler.ACTION_DISMISS
        }
        val dismissPI = PendingIntent.getBroadcast(
            this, 1, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmScheduler.ACTION_SNOOZE
        }
        val snoozePI = PendingIntent.getBroadcast(
            this, 2, snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(label)
            .setContentText(getString(R.string.alarm_ringing))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(contentPI, true)
            .setContentIntent(contentPI)
            .addAction(0, getString(R.string.snooze_btn), snoozePI)
            .addAction(0, getString(R.string.dismiss), dismissPI)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.alarm_channel_name),
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = getString(R.string.alarm_channel_desc)
                enableVibration(true)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopRinging()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "AlarmRingService"
        private const val NOTIF_ID = 9999
        private const val CHANNEL_ID = "alarm_channel"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_SNOOZE = "ACTION_SNOOZE"
    }
}
