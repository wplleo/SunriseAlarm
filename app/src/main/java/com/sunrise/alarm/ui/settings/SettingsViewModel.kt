package com.sunrise.alarm.ui.settings

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.data.ThemeMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class SettingsUiState(
    val themeMode: ThemeMode = ThemeMode.DARK,
    val appVersion: String = "1.3.0"
)

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val app = application as SunriseAlarmApp
    private val themePrefs = app.themePreferences

    private val _uiState = MutableStateFlow(SettingsUiState(themeMode = themePrefs.themeMode))
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    fun setThemeMode(mode: ThemeMode) {
        themePrefs.themeMode = mode
        _uiState.value = _uiState.value.copy(themeMode = mode)
    }

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
