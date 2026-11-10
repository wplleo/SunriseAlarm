package com.sunrise.alarm.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.sunrise.alarm.common.Lang
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 界面语言偏好：'system' | 'zh' | 'en'
 *
 * 与 [ThemePreferences] 同样的响应式写法，但存的是语言。
 * 和主题分开存是因为语义独立 —— 用户可能想「深色界面 + 英文」。
 */
class LanguagePreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _languageFlow = MutableStateFlow(getStored())
    val languageFlow: StateFlow<String> = _languageFlow.asStateFlow()

    var language: String
        get() = _languageFlow.value
        set(value) {
            prefs.edit { putString(KEY_LANGUAGE, value) }
            _languageFlow.value = value
        }

    private fun getStored(): String {
        val stored = prefs.getString(KEY_LANGUAGE, Lang.SYSTEM) ?: Lang.SYSTEM
        return if (stored == Lang.ZH || stored == Lang.EN) stored else Lang.SYSTEM
    }

    /**
     * 把已保存的偏好注入 [Lang]。
     * Application.onCreate 里调一次，保证冷启动第一帧文案就是对的；
     * 设置页切换语言时也走这里，顺带自增语言版本号触发整树重绘。
     */
    fun apply() {
        Lang.setOverride(language)
    }

    companion object {
        private const val PREFS_NAME = "language_prefs"
        private const val KEY_LANGUAGE = "language"
    }
}
