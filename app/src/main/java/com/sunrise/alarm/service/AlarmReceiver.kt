package com.sunrise.alarm.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import com.sunrise.alarm.data.AlarmDatabase
import com.sunrise.alarm.util.AlarmScheduler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 闹钟触发广播接收器
 * 收到闹钟后启动 AlarmRingService 前台服务来响铃
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "收到闹钟广播: action=${intent.action}")

        when (intent.action) {
            AlarmScheduler.ACTION_ALARM_TRIGGER -> {
                val alarmId = intent.getLongExtra(AlarmScheduler.EXTRA_ALARM_ID, -1)
                val label = intent.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: "闹钟"
                val vibrate = intent.getBooleanExtra(AlarmScheduler.EXTRA_VIBRATE, true)
                val soundUri = intent.getStringExtra(AlarmScheduler.EXTRA_SOUND_URI) ?: ""

                // 1. 获取 WakeLock，防止设备在 Service 启动前重新休眠
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK or
                            PowerManager.ACQUIRE_CAUSES_WAKEUP or
                            PowerManager.ON_AFTER_RELEASE,
                    "SunriseAlarm:AlarmReceiver"
                )
                wakeLock.acquire(10 * 1000L) // 10 秒超时保护

                // 2. 重新调度闹钟（下次触发）
                val pendingResult = goAsync()
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val dao = AlarmDatabase.getDatabase(context).alarmDao()
                        val alarm = dao.getAlarmById(alarmId)
                        if (alarm != null) {
                            if (alarm.repeatDays == 0) {
                                // 一次性闹钟：触发后自动禁用
                                dao.setEnabled(alarmId, false)
                                Log.i(TAG, "一次性闹钟已禁用: id=$alarmId")
                            } else {
                                // 重复闹钟：重新调度下次触发
                                AlarmScheduler(context).schedule(alarm)
                                Log.i(TAG, "重复闹钟已重新调度: id=$alarmId")
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "重新调度闹钟失败", e)
                    } finally {
                        pendingResult.finish()
                    }
                }

                // 3. 启动响铃服务
                val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
                    putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarmId)
                    putExtra(AlarmScheduler.EXTRA_LABEL, label)
                    putExtra(AlarmScheduler.EXTRA_VIBRATE, vibrate)
                    putExtra(AlarmScheduler.EXTRA_SOUND_URI, soundUri)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }

            AlarmScheduler.ACTION_DISMISS -> {
                val alarmId = intent.getLongExtra(AlarmScheduler.EXTRA_ALARM_ID, -1)
                val stopIntent = Intent(context, AlarmRingService::class.java).apply {
                    action = AlarmRingService.ACTION_STOP
                    putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarmId)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(stopIntent)
                } else {
                    context.startService(stopIntent)
                }
            }

            AlarmScheduler.ACTION_SNOOZE -> {
                val alarmId = intent.getLongExtra(AlarmScheduler.EXTRA_ALARM_ID, -1)
                val label = intent.getStringExtra(AlarmScheduler.EXTRA_LABEL) ?: "闹钟"
                val vibrate = intent.getBooleanExtra(AlarmScheduler.EXTRA_VIBRATE, true)
                val soundUri = intent.getStringExtra(AlarmScheduler.EXTRA_SOUND_URI) ?: ""
                val snoozeIntent = Intent(context, AlarmRingService::class.java).apply {
                    action = AlarmRingService.ACTION_SNOOZE
                    putExtra(AlarmScheduler.EXTRA_ALARM_ID, alarmId)
                    putExtra(AlarmScheduler.EXTRA_LABEL, label)
                    putExtra(AlarmScheduler.EXTRA_VIBRATE, vibrate)
                    putExtra(AlarmScheduler.EXTRA_SOUND_URI, soundUri)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(snoozeIntent)
                } else {
                    context.startService(snoozeIntent)
                }
            }
        }
    }

    companion object {
        private const val TAG = "AlarmReceiver"
    }
}
