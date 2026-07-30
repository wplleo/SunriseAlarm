package com.sunrise.alarm.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 位置信息数据
 */
data class LocationInfo(
    val name: String,          // 显示名称
    val latitude: Double,      // 纬度
    val longitude: Double,     // 经度
    val isAutoLocated: Boolean = false,
    val isCurrent: Boolean = true
)

/**
 * 位置偏好管理 —— 用 SharedPreferences 存储当前位置和已保存位置
 * currentLocation 通过 StateFlow 响应式通知，其他页面可观察变化
 */
class LocationPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ---- 响应式当前位置 ----
    private val _locationFlow = MutableStateFlow(run {
        val name = prefs.getString(KEY_CUR_NAME, null)
        if (name != null) {
            LocationInfo(
                name = name,
                latitude = prefs.getFloat(KEY_CUR_LAT, 0f).toDouble(),
                longitude = prefs.getFloat(KEY_CUR_LNG, 0f).toDouble(),
                isAutoLocated = prefs.getBoolean(KEY_CUR_AUTO, false),
                isCurrent = true
            )
        } else null
    })
    /** 其他 ViewModel 可收集此 Flow 以响应位置变化 */
    val locationFlow: StateFlow<LocationInfo?> = _locationFlow.asStateFlow()

    var autoLocate: Boolean
        get() = prefs.getBoolean(KEY_AUTO_LOCATE, true)
        set(value) = prefs.edit { putBoolean(KEY_AUTO_LOCATE, value) }

    var currentLocation: LocationInfo?
        get() = _locationFlow.value
        set(value) {
            if (value == null) {
                prefs.edit {
                    remove(KEY_CUR_NAME)
                    remove(KEY_CUR_LAT)
                    remove(KEY_CUR_LNG)
                    remove(KEY_CUR_AUTO)
                }
            } else {
                prefs.edit {
                    putString(KEY_CUR_NAME, value.name)
                    putFloat(KEY_CUR_LAT, value.latitude.toFloat())
                    putFloat(KEY_CUR_LNG, value.longitude.toFloat())
                    putBoolean(KEY_CUR_AUTO, value.isAutoLocated)
                }
            }
            // 通知所有观察者
            _locationFlow.value = value
        }

    /**
     * 获取已保存位置列表
     */
    fun getSavedLocations(): List<LocationInfo> {
        val count = prefs.getInt(KEY_SAVED_COUNT, 0)
        return (0 until count).mapNotNull { i ->
            val name = prefs.getString("${KEY_SAVED_NAME}_$i", null) ?: return@mapNotNull null
            val lat = prefs.getFloat("${KEY_SAVED_LAT}_$i", 0f).toDouble()
            val lng = prefs.getFloat("${KEY_SAVED_LNG}_$i", 0f).toDouble()
            LocationInfo(name, lat, lng, false, false)
        }
    }

    /**
     * 添加已保存位置
     */
    fun addSavedLocation(location: LocationInfo) {
        val current = getSavedLocations().toMutableList()
        // 去重
        current.removeAll { it.name == location.name }
        current.add(location)
        saveLocations(current)
    }

    /**
     * 移除已保存位置
     */
    fun removeSavedLocation(name: String) {
        val current = getSavedLocations().toMutableList()
        current.removeAll { it.name == name }
        saveLocations(current)
    }

    private fun saveLocations(locations: List<LocationInfo>) {
        val oldCount = prefs.getInt(KEY_SAVED_COUNT, 0)
        prefs.edit {
            putInt(KEY_SAVED_COUNT, locations.size)
            // 清除旧数据
            for (i in 0 until oldCount) {
                remove("${KEY_SAVED_NAME}_$i")
                remove("${KEY_SAVED_LAT}_$i")
                remove("${KEY_SAVED_LNG}_$i")
            }
            // 写入新数据
            locations.forEachIndexed { i, loc ->
                putString("${KEY_SAVED_NAME}_$i", loc.name)
                putFloat("${KEY_SAVED_LAT}_$i", loc.latitude.toFloat())
                putFloat("${KEY_SAVED_LNG}_$i", loc.longitude.toFloat())
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "location_prefs"
        private const val KEY_AUTO_LOCATE = "auto_locate"
        private const val KEY_CUR_NAME = "cur_name"
        private const val KEY_CUR_LAT = "cur_lat"
        private const val KEY_CUR_LNG = "cur_lng"
        private const val KEY_CUR_AUTO = "cur_auto"
        private const val KEY_SAVED_COUNT = "saved_count"
        private const val KEY_SAVED_NAME = "saved_name"
        private const val KEY_SAVED_LAT = "saved_lat"
        private const val KEY_SAVED_LNG = "saved_lng"
    }
}
