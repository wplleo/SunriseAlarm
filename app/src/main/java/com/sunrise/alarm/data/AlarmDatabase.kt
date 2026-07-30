package com.sunrise.alarm.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters

class AlarmTypeConverter {
    @TypeConverter
    fun fromAlarmType(type: AlarmType): String = type.name

    @TypeConverter
    fun toAlarmType(name: String): AlarmType = AlarmType.valueOf(name)
}

@Database(entities = [AlarmEntity::class], version = 1, exportSchema = false)
@TypeConverters(AlarmTypeConverter::class)
abstract class AlarmDatabase : RoomDatabase() {
    abstract fun alarmDao(): AlarmDao

    companion object {
        @Volatile
        private var INSTANCE: AlarmDatabase? = null

        fun getDatabase(context: Context): AlarmDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AlarmDatabase::class.java,
                    "sunrise_alarm_db"
                ).fallbackToDestructiveMigration().build()
                INSTANCE = instance
                instance
            }
        }
    }
}
