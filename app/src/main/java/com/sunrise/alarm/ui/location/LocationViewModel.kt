package com.sunrise.alarm.ui.location

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.sunrise.alarm.SunriseAlarmApp
import com.sunrise.alarm.common.t
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
    val message: String = "",
    /**
     * 这条提示是不是错误提示（决定显示成红色还是绿色）。
     *
     * 早先是拿 message 里有没有「失败」「未找到」来判断颜色的 —— 一上英文就永远判成
     * 绿色，出错也看着像成功。颜色不能靠文案内容猜，让 ViewModel 直接给结论。
     */
    val isError: Boolean = false
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
            _uiState.value = _uiState.value.copy(isLocating = true, message = "", isError = false)
            val loc = locationService.getCurrentLocation()
            if (loc != null) {
                locationPrefs.currentLocation = loc
                locationPrefs.addSavedLocation(loc)
                refreshFromPrefs()
                _uiState.value = _uiState.value.copy(isLocating = false, message = t("location.locateSuccess", loc.name), isError = false)
            } else {
                _uiState.value = _uiState.value.copy(isLocating = false, message = t("location.locateFailed"), isError = true)
            }
        }
    }

    fun setSearchQuery(text: String) {
        _uiState.value = _uiState.value.copy(searchQuery = text, searchResults = emptyList(), message = "", isError = false)
    }

    fun searchLocation() {
        val query = _uiState.value.searchQuery.trim()
        if (query.isEmpty()) {
            _uiState.value = _uiState.value.copy(message = t("location.searchEmpty"), isError = true)
            return
        }

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSearching = true, message = t("location.searching"), isError = false)
            val results = locationService.searchCities(query)
            if (results.isNotEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isSearching = false,
                    searchResults = results,
                    message = "",
                    isError = false
                )
            } else {
                _uiState.value = _uiState.value.copy(
                    isSearching = false,
                    searchResults = emptyList(),
                    message = t("location.searchNoResult", query),
                    isError = true
                )
            }
        }
    }

    fun selectLocation(loc: LocationInfo) {
        val newLoc = loc.copy(isCurrent = true)
        locationPrefs.currentLocation = newLoc  // 触发 StateFlow
        locationPrefs.addSavedLocation(newLoc)
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = t("location.switched", loc.name), isError = false)
    }

    fun selectSavedLocation(loc: LocationInfo) {
        val newLoc = loc.copy(isCurrent = true)
        locationPrefs.currentLocation = newLoc  // 触发 StateFlow
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = t("location.switched", loc.name), isError = false)
    }

    fun addManualLocation(lat: Double, lng: Double, name: String) {
        val loc = LocationInfo(name, lat, lng, false, true)
        locationPrefs.currentLocation = loc  // 触发 StateFlow
        locationPrefs.addSavedLocation(loc)
        refreshFromPrefs()
        _uiState.value = _uiState.value.copy(message = t("location.switched", name), isError = false)
    }

    fun clearMessage() {
        _uiState.value = _uiState.value.copy(message = "", isError = false)
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
