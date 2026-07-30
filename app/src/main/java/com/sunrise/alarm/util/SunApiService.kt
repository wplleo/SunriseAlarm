package com.sunrise.alarm.util

import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * 天文台在线日出日落 API 服务
 * 使用 sunrise-sunset.org 免费 API 校准离线计算结果
 * 网络不可用时自动回退到 NOAA 离线算法
 */
object SunApiService {

    private const val TAG = "SunApiService"
    private const val API_URL = "https://api.sunrise-sunset.org/json"
    private const val TIMEOUT_MS = 5000

    data class OnlineSunTimes(
        val sunrise: Calendar,
        val sunset: Calendar,
        val solarNoon: Calendar,
        val daylightMinutes: Int
    )

    /**
     * 从 API 获取日出日落时间
     * @param latitude 纬度
     * @param longitude 经度
     * @return OnlineSunTimes 或 null（网络错误）
     */
    fun fetchSunTimes(latitude: Double, longitude: Double): OnlineSunTimes? {
        val today = Calendar.getInstance()
        return fetchSunTimes(latitude, longitude, today)
    }

    fun fetchSunTimes(latitude: Double, longitude: Double, cal: Calendar): OnlineSunTimes? {
        val dateStr = String.format("%04d-%02d-%02d",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH))

        val urlStr = "$API_URL?lat=$latitude&lng=$longitude&date=$dateStr&formatted=0"

        return try {
            val url = URL(urlStr)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = TIMEOUT_MS
                readTimeout = TIMEOUT_MS
                setRequestProperty("Accept", "application/json")
            }

            val responseCode = conn.responseCode
            if (responseCode != 200) {
                Log.w(TAG, "API 返回错误码: $responseCode")
                return null
            }

            val body = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()

            parseResponse(body)
        } catch (e: Exception) {
            Log.w(TAG, "API 请求失败，回退到离线计算: ${e.message}")
            null
        }
    }

    private fun parseResponse(json: String): OnlineSunTimes? {
        return try {
            // 简单 JSON 解析（不引入额外依赖）
            val sunriseStr = extractField(json, "sunrise") ?: return null
            val sunsetStr = extractField(json, "sunset") ?: return null
            val noonStr = extractField(json, "solar_noon") ?: return null

            val sunrise = parseIso8601(sunriseStr) ?: return null
            val sunset = parseIso8601(sunsetStr) ?: return null
            val noon = parseIso8601(noonStr) ?: return null

            // day_length 是 JSON 数字（非字符串），extractField 无法解析
            // 直接从 sunrise/sunset 时间差计算白昼时长（分钟）
            val daylightMinutes = ((sunset.timeInMillis - sunrise.timeInMillis) / 60000L).toInt()

            OnlineSunTimes(
                sunrise = sunrise,
                sunset = sunset,
                solarNoon = noon,
                daylightMinutes = daylightMinutes
            )
        } catch (e: Exception) {
            Log.e(TAG, "解析 API 响应失败", e)
            null
        }
    }

    private fun extractField(json: String, field: String): String? {
        val key = "\"$field\":\""
        val start = json.indexOf(key)
        if (start < 0) return null
        val valueStart = start + key.length
        val valueEnd = json.indexOf("\"", valueStart)
        if (valueEnd < 0) return null
        return json.substring(valueStart, valueEnd)
    }

    private fun parseIso8601(dateStr: String): Calendar? {
        return try {
            // API 返回格式: "2024-07-29T21:48:00+00:00"
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            val date = sdf.parse(dateStr) ?: return null
            Calendar.getInstance().apply { time = date }
        } catch (e: Exception) {
            // 尝试不带时区冒号的格式
            try {
                val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssX", Locale.US)
                sdf.timeZone = TimeZone.getTimeZone("UTC")
                val date = sdf.parse(dateStr) ?: return null
                Calendar.getInstance().apply { time = date }
            } catch (e2: Exception) {
                null
            }
        }
    }
}
