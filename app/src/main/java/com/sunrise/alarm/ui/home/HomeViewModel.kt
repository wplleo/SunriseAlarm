package com.sunrise.alarm.ui.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.data.AlarmEntity
import com.sunrise.alarm.data.AlarmType
import com.sunrise.alarm.data.LocationInfo
import com.sunrise.alarm.util.SunApiService
import com.sunrise.alarm.util.SunriseSunsetCalculator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Calendar

data class HomeUiState(
    val location: LocationInfo? = null,
    val sunriseTime: String = "--:--",
    val sunsetTime: String = "--:--",
    val daylightText: String = "--",
    val sunProgress: Float = 0f,
    val alarms: List<AlarmEntity> = emptyList(),
    val nextAlarmText: String = "",
    val isLoading: Boolean = true,
    val isLocating: Boolean = false,
    val timeSource: String = ""  // "天文台在线" or "离线计算"
)

class HomeViewModel(
    application: Application
) : AndroidViewModel(application) {

    private val app = application as SunriseAlarmApp
    private val repo = app.alarmRepository
    private val locationPrefs = app.locationPreferences
    private val locationService = app.locationService

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        observeAlarms()
        observeLocationChanges()
        refreshLocation()
    }

    /**
     * 观察位置变化 —— 当用户在位置页搜索并切换城市后，自动重算日出日落
     */
    private fun observeLocationChanges() {
        viewModelScope.launch {
            locationPrefs.locationFlow.collect { loc ->
                if (loc != null) {
                    updateSunInfo()
                }
            }
        }
    }

    private fun observeAlarms() {
        viewModelScope.launch {
            repo.allAlarms.collect { alarms ->
                val sunInfo = calculateSunInfoOffline()
                val nextAlarm = calculateNextAlarm(alarms)
                _uiState.value = _uiState.value.copy(
                    alarms = alarms,
                    nextAlarmText = nextAlarm,
                    isLoading = false,
                    location = sunInfo?.third ?: locationPrefs.currentLocation,
                    sunriseTime = sunInfo?.first ?: "--:--",
                    sunsetTime = sunInfo?.second ?: "--:--",
                    daylightText = sunInfo?.fourth ?: "--",
                    sunProgress = sunInfo?.fifth ?: 0f,
                    timeSource = if (sunInfo != null) "离线计算" else ""
                )
            }
        }
    }

    fun refreshLocation() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLocating = true)

            // 先用缓存位置即时显示
            val cachedLoc = locationService.getCachedLocation()
            if (cachedLoc != null && locationPrefs.currentLocation == null) {
                locationPrefs.currentLocation = cachedLoc
                updateSunInfo()
            }

            // 如果已有保存的位置，先显示
            if (locationPrefs.currentLocation == null && cachedLoc != null) {
                locationPrefs.currentLocation = cachedLoc
                updateSunInfo()
            }

            // 请求精确定位
            if (locationPrefs.autoLocate) {
                val loc = locationService.getCurrentLocation()
                if (loc != null) {
                    locationPrefs.currentLocation = loc
                    updateSunInfo()
                } else {
                    // 定位失败 —— 3秒后重试一次
                    delay(3000L)
                    val retry = locationService.getCurrentLocation()
                    if (retry != null) {
                        locationPrefs.currentLocation = retry
                        updateSunInfo()
                    }
                }
            }

            _uiState.value = _uiState.value.copy(isLocating = false)
        }
    }

    private suspend fun updateSunInfo() {
        // 1. 先用离线算法即时显示
        val sunInfo = withContext(Dispatchers.Default) { calculateSunInfoOffline() }
        if (sunInfo != null) {
            _uiState.value = _uiState.value.copy(
                location = sunInfo.third,
                sunriseTime = sunInfo.first,
                sunsetTime = sunInfo.second,
                daylightText = sunInfo.fourth,
                sunProgress = sunInfo.fifth,
                timeSource = "离线计算"
            )
        }

        // 2. 后台尝试在线 API 校准
        val loc = locationPrefs.currentLocation
        if (loc != null) {
            val onlineResult = withContext(Dispatchers.IO) {
                SunApiService.fetchSunTimes(loc.latitude, loc.longitude)
            }
            if (onlineResult != null) {
                val sunriseStr = SunriseSunsetCalculator.formatTime(onlineResult.sunrise)
                val sunsetStr = SunriseSunsetCalculator.formatTime(onlineResult.sunset)
                val daylightStr = SunriseSunsetCalculator.formatDaylight(onlineResult.daylightMinutes)

                val now = System.currentTimeMillis()
                val sunriseMs = onlineResult.sunrise.timeInMillis
                val sunsetMs = onlineResult.sunset.timeInMillis
                val progress = when {
                    now < sunriseMs -> 0f
                    now > sunsetMs -> 1f
                    else -> ((now - sunriseMs).toFloat() / (sunsetMs - sunriseMs)).coerceIn(0f, 1f)
                }

                _uiState.value = _uiState.value.copy(
                    sunriseTime = sunriseStr,
                    sunsetTime = sunsetStr,
                    daylightText = daylightStr,
                    sunProgress = progress,
                    timeSource = "天文台在线"
                )
            }
        }
    }

    /**
     * 离线计算日出日落信息
     * 返回 (sunriseStr, sunsetStr, location, daylightStr, progress)
     */
    private fun calculateSunInfoOffline(): FiveTuple<String, String, LocationInfo?, String, Float>? {
        val loc = locationPrefs.currentLocation ?: return null
        val sunTimes = SunriseSunsetCalculator.calculateToday(loc.latitude, loc.longitude) ?: return null

        val sunriseStr = SunriseSunsetCalculator.formatTime(sunTimes.sunrise)
        val sunsetStr = SunriseSunsetCalculator.formatTime(sunTimes.sunset)
        val daylightStr = SunriseSunsetCalculator.formatDaylight(sunTimes.daylightMinutes)

        val now = System.currentTimeMillis()
        val sunriseMs = sunTimes.sunrise.timeInMillis
        val sunsetMs = sunTimes.sunset.timeInMillis
        val progress = when {
            now < sunriseMs -> 0f
            now > sunsetMs -> 1f
            else -> ((now - sunriseMs).toFloat() / (sunsetMs - sunriseMs)).coerceIn(0f, 1f)
        }

        return FiveTuple(sunriseStr, sunsetStr, loc, daylightStr, progress)
    }

    private fun calculateNextAlarm(alarms: List<AlarmEntity>): String {
        val enabled = alarms.filter { it.enabled }
        if (enabled.isEmpty()) return ""

        val loc = locationPrefs.currentLocation
        val lat = loc?.latitude ?: 22.54
        val lng = loc?.longitude ?: 113.95

        var nearestTime = Long.MAX_VALUE
        var nearestAlarm: AlarmEntity? = null

        val now = Calendar.getInstance()

        for (alarm in enabled) {
            for (dayOffset in 0..7) {
                val cal = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, dayOffset)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }

                val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
                val ourDayOfWeek = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1
                if (!alarm.isEnabledOnDay(ourDayOfWeek)) continue

                val (hour, minute) = when (alarm.type) {
                    AlarmType.REGULAR -> Pair(alarm.hour, alarm.minute)
                    AlarmType.SUNRISE -> {
                        SunriseSunsetCalculator.calculateAlarmTime(0, alarm.offsetMinutes, cal, lat, lng) ?: continue
                    }
                    AlarmType.SUNSET -> {
                        SunriseSunsetCalculator.calculateAlarmTime(1, alarm.offsetMinutes, cal, lat, lng) ?: continue
                    }
                }

                cal.set(Calendar.HOUR_OF_DAY, hour)
                cal.set(Calendar.MINUTE, minute)

                if (dayOffset == 0 && cal.timeInMillis <= now.timeInMillis) continue

                if (cal.timeInMillis < nearestTime) {
                    nearestTime = cal.timeInMillis
                    nearestAlarm = alarm
                }
                break
            }
        }

        nearestAlarm ?: return ""

        val diffMs = nearestTime - now.timeInMillis
        val diffHours = diffMs / (1000 * 60 * 60)
        val diffMins = (diffMs / (1000 * 60)) % 60

        val timeStr = String.format("%02d:%02d", nearestAlarm.let { a ->
            when (a.type) {
                AlarmType.REGULAR -> a.hour
                AlarmType.SUNRISE, AlarmType.SUNSET -> {
                    val cal = Calendar.getInstance().apply { timeInMillis = nearestTime }
                    cal.get(Calendar.HOUR_OF_DAY)
                }
            }
        }, nearestAlarm.let { a ->
            when (a.type) {
                AlarmType.REGULAR -> a.minute
                AlarmType.SUNRISE, AlarmType.SUNSET -> {
                    val cal = Calendar.getInstance().apply { timeInMillis = nearestTime }
                    cal.get(Calendar.MINUTE)
                }
            }
        })

        val typeStr = when (nearestAlarm.type) {
            AlarmType.REGULAR -> "普通闹钟"
            AlarmType.SUNRISE -> "日出闹钟"
            AlarmType.SUNSET -> "日落闹钟"
        }

        val dayStr = if (diffHours < 24) {
            if (diffHours < 1) "${diffMins}分钟后" else "还有${diffHours}小时${diffMins}分"
        } else {
            val days = diffHours / 24
            "还有${days}天"
        }

        return "${timeStr} · ${typeStr} · ${dayStr}"
    }

    fun toggleAlarm(alarm: AlarmEntity, enabled: Boolean) {
        viewModelScope.launch {
            repo.setEnabled(alarm.id, enabled)
            val updated = alarm.copy(enabled = enabled)
            if (enabled) {
                app.alarmScheduler.schedule(updated)
            } else {
                app.alarmScheduler.cancel(alarm.id)
            }
        }
    }

    fun deleteAlarm(alarm: AlarmEntity) {
        viewModelScope.launch {
            repo.delete(alarm)
            app.alarmScheduler.cancel(alarm.id)
        }
    }

    companion object {
        fun factory(app: SunriseAlarmApp): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return HomeViewModel(app as Application) as T
                }
            }
    }
}

data class FiveTuple<A, B, C, D, E>(
    val first: A, val second: B, val third: C, val fourth: D, val fifth: E
)
