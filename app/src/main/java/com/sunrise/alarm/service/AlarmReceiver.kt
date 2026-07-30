package com.sunrise.alarm.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.sunrise.alarm.util.AlarmScheduler

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
                val stopIntent = Intent(context, AlarmRingService::class.java).apply {
                    action = AlarmRingService.ACTION_STOP
                }
                context.startService(stopIntent)
            }

            AlarmScheduler.ACTION_SNOOZE -> {
                val snoozeIntent = Intent(context, AlarmRingService::class.java).apply {
                    action = AlarmRingService.ACTION_SNOOZE
                }
                context.startService(snoozeIntent)
            }
        }
    }

    companion object {
        private const val TAG = "AlarmReceiver"
    }
}
