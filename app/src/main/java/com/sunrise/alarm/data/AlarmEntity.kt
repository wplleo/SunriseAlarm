package com.sunrise.alarm.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.sunrise.alarm.common.t

/**
 * 闹钟类型
 */
enum class AlarmType {
    REGULAR,  // 普通闹钟
    SUNRISE,  // 日出闹钟
    SUNSET    // 日落闹钟
}

/**
 * 闹钟实体
 */
@Entity(tableName = "alarms")
data class AlarmEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val type: AlarmType = AlarmType.REGULAR,
    val hour: Int = 7,            // 普通闹钟使用的小时
    val minute: Int = 0,          // 普通闹钟使用的分钟
    val offsetMinutes: Int = 0,   // 日出/日落闹钟的偏移（正=延后，负=提前）
    val label: String = "",
    val enabled: Boolean = true,
    val repeatDays: Int = 0x7F,    // bit0=周一 ... bit6=周日, 0x7F=每天
    val soundName: String = "晨曦",
    val soundUri: String = "",
    val snoozeEnabled: Boolean = true,
    val snoozeMinutes: Int = 5,
    val vibrate: Boolean = true,
    val createdAt: Long = System.currentTimeMillis()
) {
    /**
     * 检查某天是否启用
     * dayOfWeek: 1=周一 ... 7=周日
     */
    fun isEnabledOnDay(dayOfWeek: Int): Boolean {
        val bit = 1 shl (dayOfWeek - 1)
        return (repeatDays and bit) != 0
    }

    /**
     * 是否每天重复
     */
    val isEveryDay: Boolean get() = repeatDays == 0x7F

    /**
     * 是否为工作日（周一至周五）
     */
    val isWeekdays: Boolean get() = repeatDays == 0x1F

    /**
     * 重复描述文本
     *
     * 走 t() 取词而不是写死中文：这段文字直接显示在首页闹钟卡片上，
     * 英文界面下漏了它就等于没做多语言。
     */
    val repeatText: String
        get() = when {
            isEveryDay -> t("alarm.repeatEveryDay")
            isWeekdays -> t("alarm.repeatWeekdays")
            repeatDays == 0 -> t("alarm.repeatOnce")
            else -> {
                val dayKeys = listOf(
                    "alarm.dayMon", "alarm.dayTue", "alarm.dayWed",
                    "alarm.dayThu", "alarm.dayFri", "alarm.daySat", "alarm.daySun"
                )
                val names = mutableListOf<String>()
                for (i in 0..6) {
                    if ((repeatDays shr i) and 1 == 1) names.add(t(dayKeys[i]))
                }
                names.joinToString(t("alarm.daySeparator"))
            }
        }
}
