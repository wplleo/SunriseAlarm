package com.sunrise.alarm

import android.app.Application
import com.sunrise.alarm.data.AlarmDatabase
import com.sunrise.alarm.data.AlarmRepository
import com.sunrise.alarm.data.LocationPreferences
import com.sunrise.alarm.data.ThemePreferences
import com.sunrise.alarm.service.LocationService
import com.sunrise.alarm.util.AlarmScheduler

class SunriseAlarmApp : Application() {

    val database by lazy { AlarmDatabase.getDatabase(this) }
    val alarmRepository by lazy { AlarmRepository(database.alarmDao()) }
    val locationPreferences by lazy { LocationPreferences(this) }
    val locationService by lazy { LocationService(this) }
    val alarmScheduler by lazy { AlarmScheduler(this) }
    val themePreferences by lazy { ThemePreferences(this) }
}
