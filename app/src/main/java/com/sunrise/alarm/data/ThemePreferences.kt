package com.sunrise.alarm.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 主题模式：深色 / 浅色 / 跟随系统
 */
enum class ThemeMode(val label: String) {
    DARK("深色模式"),
    LIGHT("浅色模式"),
    SYSTEM("跟随系统")
}

/**
 * 主题偏好管理 —— 支持响应式更新
 */
class ThemePreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _themeModeFlow = MutableStateFlow(getStoredMode())
    val themeModeFlow: StateFlow<ThemeMode> = _themeModeFlow.asStateFlow()

    var themeMode: ThemeMode
        get() = _themeModeFlow.value
        set(value) {
            prefs.edit { putString(KEY_THEME_MODE, value.name) }
            _themeModeFlow.value = value
        }

    private fun getStoredMode(): ThemeMode {
        val name = prefs.getString(KEY_THEME_MODE, ThemeMode.DARK.name) ?: ThemeMode.DARK.name
        return runCatching { ThemeMode.valueOf(name) }.getOrDefault(ThemeMode.DARK)
    }

    companion object {
        private const val PREFS_NAME = "theme_prefs"
        private const val KEY_THEME_MODE = "theme_mode"
    }
}
