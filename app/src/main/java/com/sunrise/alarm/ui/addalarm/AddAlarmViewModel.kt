package com.sunrise.alarm.ui.addalarm

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.data.AlarmEntity
import com.sunrise.alarm.data.AlarmType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class AddAlarmUiState(
    val alarmId: Long = -1,
    val type: AlarmType = AlarmType.REGULAR,
    val hour: Int = 7,
    val minute: Int = 0,
    val offsetMinutes: Int = 0,
    val label: String = "",
    val repeatDays: Int = 0x7F,
    val soundName: String = "默认铃声",
    val soundUri: String = "",
    val snoozeEnabled: Boolean = true,
    val vibrate: Boolean = true,
    val isEditing: Boolean = false,
    val isSaved: Boolean = false
)

class AddAlarmViewModel(
    application: Application,
    private val editAlarmId: Long
) : AndroidViewModel(application) {

    private val app = application as SunriseAlarmApp
    private val repo = app.alarmRepository

    private val _uiState = MutableStateFlow(AddAlarmUiState())
    val uiState: StateFlow<AddAlarmUiState> = _uiState.asStateFlow()

    init {
        if (editAlarmId > 0) loadAlarm(editAlarmId)
    }

    private fun loadAlarm(id: Long) {
        viewModelScope.launch {
            val alarm = repo.getAlarmById(id) ?: return@launch
            _uiState.value = AddAlarmUiState(
                alarmId = alarm.id,
                type = alarm.type,
                hour = alarm.hour,
                minute = alarm.minute,
                offsetMinutes = alarm.offsetMinutes,
                label = alarm.label,
                repeatDays = alarm.repeatDays,
                soundName = alarm.soundName,
                soundUri = alarm.soundUri,
                snoozeEnabled = alarm.snoozeEnabled,
                vibrate = alarm.vibrate,
                isEditing = true
            )
        }
    }

    fun setType(type: AlarmType) { _uiState.value = _uiState.value.copy(type = type) }
    fun setHour(h: Int) { _uiState.value = _uiState.value.copy(hour = h.coerceIn(0, 23)) }
    fun setMinute(m: Int) { _uiState.value = _uiState.value.copy(minute = m.coerceIn(0, 59)) }

    fun adjustOffset(delta: Int) {
        val current = _uiState.value.offsetMinutes
        _uiState.value = _uiState.value.copy(offsetMinutes = (current + delta).coerceIn(-180, 180))
    }

    fun setLabel(text: String) { _uiState.value = _uiState.value.copy(label = text) }

    /**
     * 设置铃声
     * @param name 显示名称
     * @param uri 铃声 URI（系统铃声的 content:// 或本地文件的 content:// 路径）
     */
    fun setSound(name: String, uri: String) {
        _uiState.value = _uiState.value.copy(soundName = name, soundUri = uri)
    }

    fun toggleDay(dayIndex: Int) {
        val current = _uiState.value.repeatDays
        val bit = 1 shl dayIndex
        _uiState.value = _uiState.value.copy(repeatDays = current xor bit)
    }

    fun setSnooze(enabled: Boolean) { _uiState.value = _uiState.value.copy(snoozeEnabled = enabled) }
    fun setVibrate(enabled: Boolean) { _uiState.value = _uiState.value.copy(vibrate = enabled) }

    fun save() {
        viewModelScope.launch {
            val state = _uiState.value
            val alarm = AlarmEntity(
                id = if (state.isEditing) state.alarmId else 0,
                type = state.type,
                hour = state.hour,
                minute = state.minute,
                offsetMinutes = state.offsetMinutes,
                label = state.label,
                enabled = true,
                repeatDays = state.repeatDays,
                soundName = state.soundName,
                soundUri = state.soundUri,
                snoozeEnabled = state.snoozeEnabled,
                vibrate = state.vibrate
            )
            val id = if (state.isEditing) {
                repo.update(alarm)
                state.alarmId
            } else {
                repo.insert(alarm)
            }
            app.alarmScheduler.schedule(alarm.copy(id = id))
            _uiState.value = _uiState.value.copy(isSaved = true)
        }
    }

    companion object {
        fun factory(app: SunriseAlarmApp, alarmId: Long): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return AddAlarmViewModel(app as Application, alarmId) as T
                }
            }
    }
}
