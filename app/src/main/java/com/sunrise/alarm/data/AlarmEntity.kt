package com.sunrise.alarm.data

import androidx.room.Entity
import androidx.room.PrimaryKey

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
     */
    val repeatText: String
        get() = when {
            isEveryDay -> "每天"
            isWeekdays -> "周一至周五"
            repeatDays == 0 -> "仅一次"
            else -> {
                val names = mutableListOf<String>()
                val dayNames = listOf("一", "二", "三", "四", "五", "六", "日")
                for (i in 0..6) {
                    if ((repeatDays shr i) and 1 == 1) names.add("周${dayNames[i]}")
                }
                names.joinToString("、")
            }
        }
}
