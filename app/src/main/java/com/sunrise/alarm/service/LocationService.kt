package com.sunrise.alarm.service

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Address
import android.location.Location
import android.os.Build
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.sunrise.alarm.data.LocationInfo
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import kotlin.coroutines.resume

/**
 * 位置服务 —— 封装 FusedLocationProviderClient
 *
 * FusedLocationProvider 在硬件层自动融合 GPS + 北斗 + GLONASS + Galileo 所有可用卫星系统，
 * 无需额外代码，手机芯片会自动选择最优卫星组合。
 *
 * 定位策略（三段式）：
 * 1. lastLocation —— 系统缓存，瞬间返回，30分钟内有效
 * 2. BALANCED —— WiFi/基站定位，5秒内出结果（室内也能用）
 * 3. HIGH_ACCURACY —— GPS定位，15秒超时（精度最高但冷启动慢）
 *
 * 地理编码策略：
 * 1. Android Geocoder（系统内置，可能依赖 Google 服务）
 * 2. 在线 Nominatim API fallback（不依赖 Google 服务，适合国产设备）
 */
class LocationService(private val context: Context) {

    companion object {
        private const val TAG = "LocationService"
    }

    private val fusedClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 快速获取位置 —— 三段式策略
     */
    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): LocationInfo? {
        if (!hasLocationPermission()) return null

        // 1. 先尝试 lastLocation
        val cachedLoc = getLastLocationSync()
        if (cachedLoc != null && isRecent(cachedLoc, 30)) {
            return buildLocationInfo(cachedLoc)
        }

        // 2. BALANCED 快速定位
        val balancedLoc = requestLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5000L)
        if (balancedLoc != null) {
            return buildLocationInfo(balancedLoc)
        }

        // 3. HIGH_ACCURACY GPS 定位
        val gpsLoc = requestLocation(Priority.PRIORITY_HIGH_ACCURACY, 15000L)
        if (gpsLoc != null) {
            return buildLocationInfo(gpsLoc)
        }

        // 4. 用过期的缓存位置
        if (cachedLoc != null) {
            return buildLocationInfo(cachedLoc)
        }

        return null
    }

    @SuppressLint("MissingPermission")
    suspend fun getCachedLocation(): LocationInfo? {
        if (!hasLocationPermission()) return null
        val loc = getLastLocationSync() ?: return null
        return buildLocationInfo(loc)
    }

    @SuppressLint("MissingPermission")
    private suspend fun getLastLocationSync(): Location? {
        return try {
            withTimeoutOrNull(2000L) {
                suspendCancellableCoroutine<Location?> { cont ->
                    fusedClient.lastLocation
                        .addOnSuccessListener { if (cont.isActive) cont.resume(it) }
                        .addOnFailureListener { if (cont.isActive) cont.resume(null) }
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    @SuppressLint("MissingPermission")
    private suspend fun requestLocation(priority: Int, timeoutMs: Long): Location? {
        return try {
            withTimeoutOrNull(timeoutMs) {
                suspendCancellableCoroutine<Location?> { cont ->
                    val locationRequest = LocationRequest.Builder(priority, 0L)
                        .setWaitForAccurateLocation(false)
                        .setMinUpdateIntervalMillis(0L)
                        .setMaxUpdateDelayMillis(0L)
                        .setMaxUpdates(1)
                        .build()

                    val callback = object : LocationCallback() {
                        override fun onLocationResult(result: LocationResult) {
                            val loc = result.lastLocation
                            if (cont.isActive) {
                                cont.resume(loc)
                            }
                        }
                    }

                    fusedClient.requestLocationUpdates(
                        locationRequest,
                        callback,
                        Looper.getMainLooper()
                    )

                    cont.invokeOnCancellation {
                        try {
                            fusedClient.removeLocationUpdates(callback)
                        } catch (e: Exception) {
                            // 忽略
                        }
                    }
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun isRecent(loc: Location, maxAgeMinutes: Int): Boolean {
        val ageMs = System.currentTimeMillis() - loc.time
        return ageMs < maxAgeMinutes * 60 * 1000L
    }

    private suspend fun buildLocationInfo(loc: Location): LocationInfo {
        val name = reverseGeocode(loc.latitude, loc.longitude)
        return LocationInfo(
            name = name ?: "当前位置",
            latitude = loc.latitude,
            longitude = loc.longitude,
            isAutoLocated = true,
            isCurrent = true
        )
    }

    /**
     * 反向地理编码 —— 将经纬度转为地名
     * 策略：先用 Android Geocoder，失败再用在线 Nominatim API
     */
    private suspend fun reverseGeocode(lat: Double, lng: Double): String? {
        // 1. Android Geocoder
        val geocoderResult = geocoderReverseLookup(lat, lng)
        if (geocoderResult != null) return geocoderResult

        // 2. 在线 fallback
        return nominatimReverseLookup(lat, lng)
    }

    private suspend fun geocoderReverseLookup(lat: Double, lng: Double): String? {
        return try {
            val geocoder = Geocoder(context, Locale.getDefault())
            val addresses = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // API 33+ 异步回调 —— 必须用 suspendCancellableCoroutine 等待
                withTimeoutOrNull(5000L) {
                    suspendCancellableCoroutine<List<Address>> { cont ->
                        geocoder.getFromLocation(lat, lng, 1) { addresses ->
                            if (cont.isActive) {
                                cont.resume(addresses)
                            }
                        }
                    }
                } ?: emptyList()
            } else {
                @Suppress("DEPRECATION")
                geocoder.getFromLocation(lat, lng, 1) ?: emptyList()
            }
            addresses.firstOrNull()?.let { addr ->
                addr.locality
                    ?: addr.subLocality
                    ?: addr.adminArea
                    ?: addr.getAddressLine(0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Geocoder 反向地理编码失败", e)
            null
        }
    }

    /**
     * 正向地理编码 —— 搜索城市名转经纬度
     * 策略：同时尝试 Android Geocoder 和在线 Nominatim API，合并去重后返回列表
     */
    suspend fun searchCities(query: String): List<LocationInfo> {
        val results = mutableListOf<LocationInfo>()
        val seen = mutableSetOf<Pair<Double, Double>>()

        // 1. Android Geocoder
        val geocoderResults = geocoderForwardLookup(query)
        for (loc in geocoderResults) {
            val key = Pair(
                String.format("%.3f", loc.latitude).toDouble(),
                String.format("%.3f", loc.longitude).toDouble()
            )
            if (seen.add(key)) results.add(loc)
        }

        // 2. 如果 Geocoder 没找到，或结果太少，尝试 Nominatim
        if (results.size < 3) {
            val nominatimResults = nominatimForwardLookup(query)
            for (loc in nominatimResults) {
                val key = Pair(
                    String.format("%.3f", loc.latitude).toDouble(),
                    String.format("%.3f", loc.longitude).toDouble()
                )
                if (seen.add(key)) results.add(loc)
            }
        }

        return results.take(5)
    }

    /** 旧接口兼容 */
    suspend fun searchCity(query: String): LocationInfo? = searchCities(query).firstOrNull()

    private suspend fun geocoderForwardLookup(query: String): List<LocationInfo> {
        return try {
            val geocoder = Geocoder(context, Locale.getDefault())
            val addresses = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // API 33+ 异步回调
                withTimeoutOrNull(5000L) {
                    suspendCancellableCoroutine<List<Address>> { cont ->
                        geocoder.getFromLocationName(query, 5) { addresses ->
                            if (cont.isActive) {
                                cont.resume(addresses)
                            }
                        }
                    }
                } ?: emptyList()
            } else {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(query, 5) ?: emptyList()
            }
            addresses.mapNotNull { addr ->
                val name = addr.locality
                    ?: addr.subLocality
                    ?: addr.adminArea
                    ?: addr.getAddressLine(0)?.substringBefore(",")
                    ?: query
                LocationInfo(
                    name = name,
                    latitude = addr.latitude,
                    longitude = addr.longitude,
                    isAutoLocated = false,
                    isCurrent = false
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Geocoder 正向地理编码失败", e)
            emptyList()
        }
    }

    // ---- 在线 Nominatim API fallback ----

    private suspend fun nominatimReverseLookup(lat: Double, lng: Double): String? {
        return try {
            val urlStr = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10&accept-language=zh"
            val json = httpGet(urlStr) ?: return null
            // 简单解析 JSON
            val cityName = extractNominatimName(json)
            cityName
        } catch (e: Exception) {
            Log.e(TAG, "Nominatim 反向地理编码失败", e)
            null
        }
    }

    private suspend fun nominatimForwardLookup(query: String): List<LocationInfo> {
        return try {
            val encoded = URLEncoder.encode(query, "UTF-8")
            val urlStr = "https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=5&accept-language=zh-CN&addressdetails=1"
            val json = httpGet(urlStr) ?: return emptyList()
            parseNominatimSearchResults(json)
        } catch (e: Exception) {
            Log.e(TAG, "Nominatim 正向地理编码失败", e)
            emptyList()
        }
    }

    private fun parseNominatimSearchResults(json: String): List<LocationInfo> {
        val results = mutableListOf<LocationInfo>()
        val objectRegex = Regex("""\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}""")
        for (match in objectRegex.findAll(json)) {
            val obj = match.value
            val lat = extractJsonField(obj, "lat")?.toDoubleOrNull()
            if (lat == null) continue
            val lon = extractJsonField(obj, "lon")?.toDoubleOrNull()
            if (lon == null) continue

            // 优先从 address 子对象提取城市名
            var name: String? = extractNominatimAddressName(obj)
            if (name == null) {
                val displayName = extractJsonField(obj, "display_name")
                name = displayName?.substringBefore(",")
            }
            if (name.isNullOrBlank()) continue

            results.add(LocationInfo(
                name = name,
                latitude = lat,
                longitude = lon,
                isAutoLocated = false,
                isCurrent = false
            ))
            if (results.size >= 5) break
        }
        return results
    }

    private fun extractNominatimAddressName(obj: String): String? {
        // 尝试从 address 子对象中提取城市名
        for (field in listOf("city", "town", "village", "county", "state", "municipality", "suburb", "hamlet")) {
            val value = extractJsonField(obj, field)
            if (value != null) return value
        }
        return null
    }

    private suspend fun httpGet(urlStr: String): String? {
        return try {
            withTimeoutOrNull(8000L) {
                val url = URL(urlStr)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.setRequestProperty("User-Agent", "SunriseAlarm/1.0")
                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val sb = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        sb.append(line)
                    }
                    reader.close()
                    sb.toString()
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "HTTP 请求失败: $urlStr", e)
            null
        }
    }

    private fun extractJsonField(json: String, field: String): String? {
        val pattern = "\"$field\"\\s*:\\s*\"([^\"]+)\""
        val regex = Regex(pattern)
        return regex.find(json)?.groupValues?.getOrNull(1)
    }

    private fun extractNominatimName(json: String): String? {
        // 尝试提取 city, town, village, county, state 字段
        for (field in listOf("city", "town", "village", "county", "state", "suburb")) {
            val value = extractJsonField(json, field)
            if (value != null) return value
        }
        // 最后用 display_name 的第一部分
        val displayName = extractJsonField(json, "display_name")
        return displayName?.substringBefore(",")
    }
}
