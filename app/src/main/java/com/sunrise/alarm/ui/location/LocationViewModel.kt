package com.sunrise.alarm.ui.location

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.data.LocationInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class LocationUiState(
    val currentLocation: LocationInfo? = null,
    val autoLocate: Boolean = true,
    val savedLocations: List<LocationInfo> = emptyList(),
    val searchQuery: String = "",
    val searchResults: List<LocationInfo> = emptyList(),
    val isLocating: Boolean = false,
    val isSearching: Boolean = false,
    val message: String = ""
)

class LocationViewModel(
    application: Application
) : AndroidViewModel(application) {

    private val app = application as SunriseAlarmApp
    private val locationPrefs = app.locationPreferences
    private val locationService = app.locationService

    private val _uiState = MutableStateFlow(LocationUiState())
    val uiState: StateFlow<LocationUiState> = _uiState.asStateFlow()

    init {
        refreshFromPrefs()
    }

    private fun refreshFromPrefs() {
        _uiState.value = _uiState.value.copy(
            currentLocation = locationPrefs.currentLocation,
            autoLocate = locationPrefs.autoLocate,
            savedLocations = locationPrefs.getSavedLocations()
        )
    }

    fun toggleAutoLocate(enabled: Boolean) {
        locationPrefs.autoLocate = enabled
        _uiState.value = _uiState.value.copy(autoLocate = enabled)
        if (enabled) {
            locateNow()
        }
    }

    fun locateNow() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLocating = true, message = "")
            val loc = locationService.getCurrentLocation()
            if (loc != null) {
                locationPrefs.currentLocation = loc
                locationPrefs.addSavedLocation(loc)
                refreshFromPrefs()
                _uiState.value = _uiState.value.copy(isLocating = false, message = "定位成功：${loc.name}")
            } else {
                _uiState.value = _uiState.value.copy(isLocating = false, message = "定位失败，请检查位置权限")
            }
        }
    }

    fun setSearchQuery(text: String) {
        _uiState.value = _uiState.value.copy(searchQuery = text, searchResults = emptyList(), message = "")
    }

    fun searchLocation() {
        val query = _uiState.value.searchQuery.trim()
        if (query.isEmpty()) {
            _uiState.value = _uiState.value.copy(message = "请输入搜索内容")
            return
        }

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSearching = true, message = "搜索中...")
            val results = locationService.searchCities(query)
            if (results.isNotEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isSearching = false,
                    searchResults = results,
                    message = "找到 ${results.size} 个结果"
                )
            } else {
                _uiState.value = _uiState.value.copy(
                    isSearching = false,
                    searchResults = emptyList(),
                    message = "未找到「$query」，换个关键词试试"
                )
            }
        }
    }

    fun selectLocation(loc: LocationInfo) {
        val newLoc = loc.copy(isCurrent = true)
        locationPrefs.currentLocation = newLoc  // 触发 StateFlow
        locationPrefs.addSavedLocation(newLoc)
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = "已切换到 ${loc.name}")
    }

    fun selectSavedLocation(loc: LocationInfo) {
        val newLoc = loc.copy(isCurrent = true)
        locationPrefs.currentLocation = newLoc  // 触发 StateFlow
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = "已切换到 ${loc.name}")
    }

    fun addManualLocation(lat: Double, lng: Double, name: String) {
        val loc = LocationInfo(name, lat, lng, false, true)
        locationPrefs.currentLocation = loc  // 触发 StateFlow
        locationPrefs.addSavedLocation(loc)
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = "已添加 $name")
    }

    fun clearMessage() {
        _uiState.value = _uiState.value.copy(message = "")
    }

    companion object {
        fun factory(app: SunriseAlarmApp): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return LocationViewModel(app as Application) as T
                }
            }
    }
}
