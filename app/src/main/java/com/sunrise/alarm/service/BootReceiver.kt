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
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            Log.i(TAG, "开机/更新完成，重新注册闹钟")
            CoroutineScope(Dispatchers.IO).launch {
                val dao = AlarmDatabase.getDatabase(context).alarmDao()
                val scheduler = AlarmScheduler(context)
                val alarms = dao.getEnabledAlarms()
                scheduler.rescheduleAll(alarms)
            }
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
