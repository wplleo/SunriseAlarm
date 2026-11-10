package com.sunrise.alarm.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

/**
 * 隐私政策同意状态 —— 与鸿蒙版 common/PrivacyConsent.ets 对齐
 *
 * 合规要求（对应国内商店审核「首次启动未提示阅读隐私政策」一类驳回）：
 *  - 首次启动必须以显著方式提示用户阅读隐私政策，由用户主动同意
 *  - 未取得同意前，不得申请定位权限、不得联网、不得上报带位置信息的数据
 *
 * 单独用一个 preferences 文件存放，避免与业务设置耦合：
 * 即便主题/语言偏好读写异常，隐私状态也要能正常判断。
 */
object PrivacyConsent {

    /** 隐私政策版本号。条款有实质变化时递增，用户会被重新提示确认 */
    const val PRIVACY_VERSION = "1.0"

    private const val PREFS_NAME = "sunrise_privacy"
    private const val KEY_AGREED = "agreed"
    private const val KEY_AGREED_VERSION = "agreedVersion"

    @Volatile
    private var prefs: SharedPreferences? = null

    /** 内存缓存，供同步判断；Compose 首帧渲染时不用等异步 */
    @Volatile
    private var agreedCache: Boolean = false

    /** 重复调用安全 */
    fun init(context: Context) {
        if (prefs != null) return
        synchronized(this) {
            if (prefs != null) return
            val p = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs = p
            val has = p.getBoolean(KEY_AGREED, false)
            val ver = p.getString(KEY_AGREED_VERSION, "") ?: ""
            // 版本不一致视为未同意，需要重新确认
            agreedCache = has && ver == PRIVACY_VERSION
        }
    }

    /** 是否已同意当前版本隐私政策（同步） */
    fun isAgreed(): Boolean = agreedCache

    /** 用户点击「同意并继续」 */
    fun agree() {
        agreedCache = true
        prefs?.edit {
            putBoolean(KEY_AGREED, true)
            putString(KEY_AGREED_VERSION, PRIVACY_VERSION)
        }
    }

    /** 撤回同意（留给以后做「隐私设置」入口，当前未接线） */
    fun revoke() {
        agreedCache = false
        prefs?.edit { putBoolean(KEY_AGREED, false) }
    }
}
