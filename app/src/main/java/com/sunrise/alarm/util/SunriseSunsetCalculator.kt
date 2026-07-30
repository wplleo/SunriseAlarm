package com.sunrise.alarm.util

import java.util.Calendar
import java.util.TimeZone
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.floor

/**
 * 日出日落时间计算器
 * 基于 NOAA (National Oceanic and Atmospheric Administration) 算法
 * 完全离线计算，不需要网络请求
 *
 * 参考: https://gml.noaa.gov/grad/solcalc/calcdetails.html
 */
object SunriseSunsetCalculator {

    data class SunTimes(
        val sunrise: Calendar,
        val sunset: Calendar,
        val solarNoon: Calendar,
        val daylightMinutes: Int  // 白昼时长（分钟）
    )

    /**
     * 计算指定日期、位置的日出日落时间
     *
     * @param year 年
     * @param month 月 (1-12)
     * @param day 日
     * @param latitude 纬度 (度)
     * @param longitude 经度 (度)
     * @param timeZone 时区偏移 (小时)
     * @return SunTimes 或 null（极昼/极夜情况）
     */
    fun calculate(
        year: Int,
        month: Int,
        day: Int,
        latitude: Double,
        longitude: Double,
        timeZone: Double
    ): SunTimes? {
        val latRad = Math.toRadians(latitude)

        // 1. 计算儒略日
        val jd = julianDay(year, month, day)

        // 2. 计算自2000年1月1日12:00 UTC以来的儒略世纪数
        val jc = (jd - 2451545.0) / 36525.0

        // 3. 计算太阳几何平均经度（度）
        val geomMeanLong = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360.0

        // 4. 计算太阳几何平均近点角（度）
        val geomMeanAnom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc)

        // 4.5 计算地球轨道偏心率
        val eccentricity = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)

        // 5. 计算太阳中心方程
        val sunEqCtr = sin(Math.toRadians(geomMeanAnom)) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
                sin(Math.toRadians(2 * geomMeanAnom)) * (0.019993 - 0.000101 * jc) +
                sin(Math.toRadians(3 * geomMeanAnom)) * 0.000289

        // 6. 太阳真经度
        val sunTrueLong = geomMeanLong + sunEqCtr

        // 7. 太阳视经度（考虑章动和光行差）
        val sunAppLong = sunTrueLong - 0.00569 - 0.00478 * sin(Math.toRadians(125.04 - 1934.136 * jc))

        // 8. 平均黄赤交角（度）
        val meanObliqEcliptic = 23.0 + (26.0 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60.0) / 60.0

        // 9. 修正黄赤交角
        val obliqCorr = meanObliqEcliptic + 0.00256 * cos(Math.toRadians(125.04 - 1934.136 * jc))

        // 10. 太阳赤纬（度）
        val sunDeclination = Math.toDegrees(
            asin(sin(Math.toRadians(obliqCorr)) * sin(Math.toRadians(sunAppLong)))
        )

        // 11. 时差（分钟）
        // y = tan(ε/2)²
        val y = tan(Math.toRadians(obliqCorr / 2.0)).let { it * it }
        // NOAA 公式：EqT = 4 × toDeg(y·sin(2L) - 2e·sin(M) + 4e·y·sin(M)·cos(2L) - 0.5y²·sin(4L) - 1.25e²·sin(2M))
        val eqOfTime = 4.0 * Math.toDegrees(
            y * sin(2 * Math.toRadians(geomMeanLong)) -
            2.0 * eccentricity * sin(Math.toRadians(geomMeanAnom)) +
            4.0 * eccentricity * y * sin(Math.toRadians(geomMeanAnom)) * cos(2 * Math.toRadians(geomMeanLong)) -
            0.5 * y * y * sin(4 * Math.toRadians(geomMeanLong)) -
            1.25 * eccentricity * eccentricity * sin(2 * Math.toRadians(geomMeanAnom))
        )

        // 12. 日出/日落时角（度）
        // 官方日出日落使用 -0.833 度（考虑大气折射和太阳半径）
        val zenithAngle = 90.833
        val hourAngle = Math.toDegrees(
            acos(
                cos(Math.toRadians(zenithAngle)) / (cos(latRad) * cos(Math.toRadians(sunDeclination))) -
                tan(latRad) * tan(Math.toRadians(sunDeclination))
            )
        )

        // 如果 acos 的参数超出 [-1, 1]，说明是极昼或极夜
        val cosValue = cos(Math.toRadians(zenithAngle)) / (cos(latRad) * cos(Math.toRadians(sunDeclination))) -
                tan(latRad) * tan(Math.toRadians(sunDeclination))
        if (cosValue.isNaN() || abs(cosValue) > 1.0) {
            return null // 极昼或极夜
        }

        // 13. 日出/日落的中天时间（分钟，UTC）
        val solarNoonMin = (720.0 - 4.0 * longitude - eqOfTime + timeZone * 60.0)
        val sunriseMin = solarNoonMin - hourAngle * 4.0
        val sunsetMin = solarNoonMin + hourAngle * 4.0

        // 14. 转换为 Calendar
        val calSunrise = minutesToCalendar(year, month, day, sunriseMin)
        val calSunset = minutesToCalendar(year, month, day, sunsetMin)
        val calNoon = minutesToCalendar(year, month, day, solarNoonMin)

        val daylight = (sunsetMin - sunriseMin).toInt()

        return SunTimes(calSunrise, calSunset, calNoon, daylight)
    }

    /**
     * 便捷方法：计算今天的日出日落
     */
    fun calculateToday(latitude: Double, longitude: Double): SunTimes? {
        val cal = Calendar.getInstance()
        val tz = cal.timeZone.getOffset(cal.timeInMillis) / 3600000.0
        return calculate(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            latitude,
            longitude,
            tz
        )
    }

    /**
     * 便捷方法：计算指定日期的日出日落
     */
    fun calculateForDate(cal: Calendar, latitude: Double, longitude: Double): SunTimes? {
        val tz = cal.timeZone.getOffset(cal.timeInMillis) / 3600000.0
        return calculate(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH),
            latitude,
            longitude,
            tz
        )
    }

    /**
     * 计算明天某闹钟基于日出日落的实际触发时间
     * 返回 [hour, minute]
     */
    fun calculateAlarmTime(
        alarmType: Int, // 0=日出, 1=日落
        offsetMinutes: Int, // 偏移分钟（正=延后，负=提前）
        cal: Calendar,
        latitude: Double,
        longitude: Double
    ): Pair<Int, Int>? {
        val sunTimes = calculateForDate(cal, latitude, longitude) ?: return null
        val baseCal = if (alarmType == 0) sunTimes.sunrise else sunTimes.sunset
        baseCal.add(Calendar.MINUTE, offsetMinutes)
        return Pair(baseCal.get(Calendar.HOUR_OF_DAY), baseCal.get(Calendar.MINUTE))
    }

    // ---- 内部工具方法 ----

    private fun julianDay(year: Int, month: Int, day: Int): Double {
        var y = year
        var m = month
        if (m <= 2) {
            y -= 1
            m += 12
        }
        val a = floor(y / 100.0).toInt()
        val b = 2 - a + floor(a / 4.0).toInt()
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }

    private fun Double.toRad() = Math.toRadians(this)

    private fun minutesToCalendar(year: Int, month: Int, day: Int, totalMinutes: Double): Calendar {
        val cal = Calendar.getInstance()
        cal.set(Calendar.YEAR, year)
        cal.set(Calendar.MONTH, month - 1)
        cal.set(Calendar.DAY_OF_MONTH, day)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        var mins = totalMinutes
        // 处理跨天
        while (mins < 0) mins += 1440
        while (mins >= 1440) mins -= 1440

        val totalMinsInt = floor(mins).toInt()
        val hour = totalMinsInt / 60
        val min = totalMinsInt % 60
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, min)
        return cal
    }

    private fun Double.roundToInt(): Int {
        return if (this >= 0) floor(this + 0.5).toInt() else ceil(this - 0.5).toInt()
    }

    /**
     * 格式化白昼时长
     */
    fun formatDaylight(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        return "${h}时${m}分"
    }

    /**
     * 格式化时间 HH:mm
     */
    fun formatTime(cal: Calendar): String {
        return String.format("%02d:%02d",
            cal.get(Calendar.HOUR_OF_DAY),
            cal.get(Calendar.MINUTE))
    }
}
