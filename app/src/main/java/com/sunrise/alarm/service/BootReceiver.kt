package com.sunrise.alarm.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.sunrise.alarm.data.AlarmDatabase
import com.sunrise.alarm.util.AlarmScheduler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * 开机/应用更新后重新注册所有闹钟
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == Intent.ACTION_TIME_SET ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            Log.i(TAG, "系统事件(${intent.action})，重新注册闹钟")
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val dao = AlarmDatabase.getDatabase(context).alarmDao()
                    val scheduler = AlarmScheduler(context)
                    val alarms = dao.getEnabledAlarms()
                    scheduler.rescheduleAll(alarms)
                    Log.i(TAG, "已重新注册 ${alarms.size} 个闹钟")
                } catch (e: Exception) {
                    Log.e(TAG, "重新注册闹钟失败", e)
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
