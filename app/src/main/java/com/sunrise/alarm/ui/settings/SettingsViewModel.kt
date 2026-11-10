package com.sunrise.alarm.ui.settings

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.common.Lang
import com.sunrise.alarm.data.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class SettingsUiState(
    val themeMode: ThemeMode = ThemeMode.DARK,
    /** 'system' | 'zh' | 'en' */
    val language: String = Lang.SYSTEM,
    val appVersion: String = ""
)

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val app = application as SunriseAlarmApp
    private val themePrefs = app.themePreferences
    private val langPrefs = app.languagePreferences

    private val _uiState = MutableStateFlow(
        SettingsUiState(
            themeMode = themePrefs.themeMode,
            language = langPrefs.language,
            appVersion = readVersion()
        )
    )
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    fun setThemeMode(mode: ThemeMode) {
        themePrefs.themeMode = mode
        _uiState.value = _uiState.value.copy(themeMode = mode)
    }

    /**
     * 切换界面语言。
     * 写进偏好后调 [LanguagePreferences.apply]，它会自增 Lang 的版本号，
     * MainActivity 监听到之后整棵树重建 —— 三个 Tab 和底部导航一起换语言，
     * 不需要各页面自己刷新。
     */
    fun setLanguage(value: String) {
        if (langPrefs.language == value) return
        langPrefs.language = value
        langPrefs.apply()
        _uiState.value = _uiState.value.copy(language = value)
    }

    /** 从 PackageManager 读版本号，读不到显示占位符，不写死版本 */
    private fun readVersion(): String = runCatching {
        val pm = getApplication<Application>().packageManager
        val pkg = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(getApplication<Application>().packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(getApplication<Application>().packageName, 0)
        }
        pkg.versionName
    }.getOrNull() ?: "—"

    companion object {
        fun factory(app: SunriseAlarmApp): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return SettingsViewModel(app as Application) as T
                }
            }
    }
}
