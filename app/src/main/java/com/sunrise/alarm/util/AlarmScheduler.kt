package com.sunrise.alarm.util

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.sunrise.alarm.data.AlarmEntity
import com.sunrise.alarm.data.AlarmType
import com.sunrise.alarm.data.LocationPreferences
import com.sunrise.alarm.service.AlarmReceiver
import java.util.Calendar

/**
 * 闹钟调度器 —— 封装 AlarmManager
 */
class AlarmScheduler(private val context: Context) {

    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private val locationPrefs = LocationPreferences(context)

    /**
     * 调度单个闹钟
     */
    fun schedule(alarm: AlarmEntity) {
        if (!alarm.enabled) {
            cancel(alarm.id)
            return
        }

        val triggerTime = calculateTriggerTime(alarm) ?: run {
            Log.w(TAG, "无法计算闹钟触发时间，跳过: ${alarm.id}")
            return
        }

        val intent = createAlarmIntent(alarm.id, alarm.label, alarm.vibrate, alarm.soundUri)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarm.id.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                } else {
                    // 降级到非精确闹钟
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
            Log.i(TAG, "闹钟已调度: id=${alarm.id}, 触发时间=${java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date(triggerTime))}")
        } catch (e: SecurityException) {
            Log.e(TAG, "调度闹钟失败", e)
        }
    }

    /**
     * 取消闹钟
     */
    fun cancel(alarmId: Long) {
        val intent = createAlarmIntent(alarmId, "", false, "")
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId.toInt(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        pendingIntent?.let { alarmManager.cancel(it) }
    }

    /**
     * 重新调度所有启用的闹钟（开机/应用更新后调用）
     */
    suspend fun rescheduleAll(alarms: List<AlarmEntity>) {
        alarms.filter { it.enabled }.forEach { alarm ->
            schedule(alarm)
        }
    }

    /**
     * 计算闹钟的下次触发时间（毫秒时间戳）
     */
    private fun calculateTriggerTime(alarm: AlarmEntity): Long? {
        val now = Calendar.getInstance()
        val location = locationPrefs.currentLocation
        val lat = location?.latitude ?: 22.54   // 默认深圳
        val lng = location?.longitude ?: 113.95

        // 计算从今天起未来7天内最近的触发时间
        for (dayOffset in 0..7) {
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            // 检查这天是否需要响
            val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
            // Calendar.DAY_OF_WEEK: 1=周日, 2=周一 ... 7=周六
            // AlarmEntity: 1=周一 ... 7=周日
            val ourDayOfWeek = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1
            if (!alarm.isEnabledOnDay(ourDayOfWeek)) continue

            // 计算触发时间
            val (hour, minute) = when (alarm.type) {
                AlarmType.REGULAR -> Pair(alarm.hour, alarm.minute)
                AlarmType.SUNRISE -> {
                    SunriseSunsetCalculator.calculateAlarmTime(
                        0, alarm.offsetMinutes, cal, lat, lng
                    ) ?: continue
                }
                AlarmType.SUNSET -> {
                    SunriseSunsetCalculator.calculateAlarmTime(
                        1, alarm.offsetMinutes, cal, lat, lng
                    ) ?: continue
                }
            }

            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)

            // 如果是今天且时间已过，跳到下一天
            if (dayOffset == 0 && cal.timeInMillis <= now.timeInMillis) {
                continue
            }

            return cal.timeInMillis
        }

        return null
    }

    private fun createAlarmIntent(
        alarmId: Long,
        label: String,
        vibrate: Boolean,
        soundUri: String
    ): Intent {
        return Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_ALARM_TRIGGER
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_LABEL, label)
            putExtra(EXTRA_VIBRATE, vibrate)
            putExtra(EXTRA_SOUND_URI, soundUri)
        }
    }

    companion object {
        const val ACTION_ALARM_TRIGGER = "com.sunrise.alarm.ACTION_ALARM_TRIGGER"
        const val ACTION_DISMISS = "com.sunrise.alarm.ACTION_DISMISS"
        const val ACTION_SNOOZE = "com.sunrise.alarm.ACTION_SNOOZE"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_LABEL = "label"
        const val EXTRA_VIBRATE = "vibrate"
        const val EXTRA_SOUND_URI = "sound_uri"
        private const val TAG = "AlarmScheduler"
    }
}
