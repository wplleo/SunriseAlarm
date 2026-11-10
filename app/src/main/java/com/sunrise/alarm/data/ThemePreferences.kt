package com.sunrise.alarm.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 主题模式：深色 / 浅色 / 跟随系统
 *
 * 不带显示名 —— 文案统一走 common/I18n.kt 的 t()，枚举里留中文会漏翻。
 */
enum class ThemeMode {
    DARK,
    LIGHT,
    SYSTEM
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
