package com.sunrise.alarm.common

import androidx.compose.runtime.mutableStateOf
import java.util.Locale as JavaLocale

/**
 * 多语言文案 —— 与鸿蒙版 entry/src/main/ets/common/I18n.ets 逐 key 对齐。
 *
 * 设计说明（沿用鸿蒙版，两份保持一致，改动时请同步）：
 *  - 界面所有用户可见文案统一走 [t]，不在 .kt 里写死中文字符串
 *  - 词典是中英各一份的 Map；占位符写 {0} {1}，按传入顺序替换
 *  - 缺 key 时回落成 key 本身，不会崩、不会白屏
 *  - 系统语言以 zh 开头判定为中文，其余一律英文
 *
 * 为什么不用 Android 原生 values-en/strings.xml：
 * ViewModel、通知、闹钟实体里也要拼文案，那几处拿不到 Context，
 * 原生资源每个调用点都得塞一个 Context 进来。词典集中在一处反而干净，
 * 而且能和鸿蒙版逐 key 对照，两边漏翻一眼能看出来。
 * 系统直接读取的文案（应用名、权限说明、通知渠道名）仍走 res/values。
 */
object Lang {

    const val SYSTEM = "system"
    const val ZH = "zh"
    const val EN = "en"

    /** 用户在「设置 → 语言」里的选择，默认跟随系统 */
    @Volatile
    private var override: String = SYSTEM

    /** isZh 的缓存，切语言时清掉 */
    @Volatile
    private var cachedZh: Boolean? = null

    /**
     * 语言版本号。切语言时自增，MainActivity 在 setContent 里读它，
     * 一次自增就能让整棵 Compose 树重新执行、所有 t() 重新取词。
     *
     * ViewModel 里拼出来的文案（下一个闹钟、数据来源）不在这套机制里，
     * 各页面靠 LaunchedEffect(langVersion) { viewModel.refreshLocale() } 补一刀。
     */
    private val _version = mutableStateOf(0)
    val version: Int get() = _version.value

    /** 设置页切换语言时调用；Application 启动时也要按已保存的偏好注入一次 */
    fun setOverride(value: String) {
        override = value
        cachedZh = null
        _version.value += 1
    }

    fun getOverride(): String = override

    /** 当前是否中文环境 */
    fun isZh(): Boolean {
        cachedZh?.let { return it }
        val zh: Boolean = when (override) {
            ZH -> true
            EN -> false
            else -> {
                val lang = runCatching { JavaLocale.getDefault().language }.getOrDefault("zh")
                lang.lowercase().startsWith("zh")
            }
        }
        cachedZh = zh
        return zh
    }

    /** 当前语言标记，写日志用 */
    fun tag(): String = if (isZh()) "zh" else "en"

    /**
     * 系统地名解析（逆地理编码 / 正向搜索）要用的 Locale。
     *
     * 不能用 Locale.getDefault()：用户把界面切成英文、系统还是中文时，
     * 地名会跟着系统返回「东营市」，界面上就是英文标题挂着中文城市名。
     * 用户显式选了语言就按选择来；「跟随系统」时才交回系统默认值，
     * 免得非中非英的系统被我们硬掰成英文。
     *
     * 只给纯语言码：鸿蒙侧实测传 'en-US' 系统照旧返回中文地名，传 'en' 才返回 'Dongying'。
     */
    fun geocodeLocale(): JavaLocale = when (override) {
        ZH -> JavaLocale.forLanguageTag("zh")
        EN -> JavaLocale.forLanguageTag("en")
        else -> JavaLocale.getDefault()
    }

    /** 在线地名服务（Nominatim 之类）的 accept-language 参数，取纯语言码 */
    fun geocodeTag(): String = geocodeLocale().language
}

/**
 * 取文案。
 * @param key 词典 key
 * @param args 占位符参数，依次替换 {0} {1} …
 */
fun t(key: String, vararg args: Any): String {
    val dict = if (Lang.isZh()) ZH else EN
    val raw = dict[key] ?: return key
    if (args.isEmpty()) return raw
    var s = raw
    args.forEachIndexed { i, arg -> s = s.replace("{$i}", arg.toString()) }
    return s
}

/**
 * 铃声显示名。
 *
 * soundName 是存进数据库的原始值（内置预设名、系统铃声标题、或本地文件名）。
 * 切语言不会回头改数据库，所以显示时按已知的预设名映射一次，认不出来就原样显示 ——
 * 系统铃声标题和本地文件名本来就该保持用户看到的样子。
 */
fun localizedSoundName(raw: String): String = when (raw) {
    "", "默认铃声", "Default sound" -> t("sound.default")
    "晨曦", "Dawn" -> t("ring.dawn")
    "暖阳", "Warm sun" -> t("ring.warmSun")
    "清风", "Breeze" -> t("ring.breeze")
    "鸟鸣", "Birdsong" -> t("ring.birds")
    "海潮", "Ocean waves" -> t("ring.ocean")
    "轻铃", "Gentle chime" -> t("ring.chime")
    else -> raw
}

// ---------------------------------------------------------------------------
// 中文词典
// ---------------------------------------------------------------------------
// 中文词典
// ---------------------------------------------------------------------------
private val ZH: Map<String, String> = mapOf(
    "common.alarm" to "闹钟",
    "common.location" to "位置",
    "common.settings" to "设置",
    "common.save" to "保存",
    "common.add" to "添加",
    "common.delete" to "删除",
    "common.close" to "关闭",
    "common.cancel" to "取消",
    "common.confirm" to "确定",
    "common.agree" to "同意",
    "common.decline" to "不同意",
    "common.snooze" to "稍后提醒",
    "common.closeAlarm" to "关闭闹钟",
    "common.locating" to "定位中…",
    "common.appName" to "日出闹钟",
    "common.sunrise" to "日出",
    "common.sunset" to "日落",
    "common.am" to "上午",
    "common.pm" to "下午",
    "common.opFailed" to "操作失败({0})",
    "common.saveFailed" to "保存失败({0})",
    "common.deleteFailed" to "删除失败({0})",
    "common.durationHM" to "{0}时{1}分",
    "time.am" to "上午",
    "time.pm" to "下午",
    "alarm.dayMon" to "周一",
    "alarm.dayTue" to "周二",
    "alarm.dayWed" to "周三",
    "alarm.dayThu" to "周四",
    "alarm.dayFri" to "周五",
    "alarm.daySat" to "周六",
    "alarm.daySun" to "周日",
    "alarm.daySeparator" to "、",
    "alarm.repeatEveryDay" to "每天",
    "alarm.repeatWeekdays" to "周一至周五",
    "alarm.repeatOnce" to "仅一次",
    "alarm.sunrise" to "日出",
    "alarm.sunset" to "日落",
    "alarm.offsetAfter" to "{0}后 {1} 分钟",
    "alarm.offsetBefore" to "{0}前 {1} 分钟",
    "ring.systemDefault" to "系统默认",
    "ring.custom" to "自定义",
    "ring.dawn" to "晨曦",
    "ring.warmSun" to "暖阳",
    "ring.breeze" to "清风",
    "ring.birds" to "鸟鸣",
    "ring.ocean" to "海潮",
    "ring.chime" to "轻铃",
    "ring.ringing" to "闹钟响铃中",
    "ring.snoozeButton" to "稍后提醒（{0} 分钟）",
    "widget.durationHour" to "{0}小时",
    "widget.durationHourMin" to "{0}小时{1}分",
    "widget.polar" to "极昼 / 极夜",
    "widget.daylight" to "白天",
    "home.notifyOff" to "未开启通知权限，闹钟可能无法响铃",
    "home.timeSourceOffline" to "离线计算",
    "home.timeSourceOnline" to "天文台在线",
    "home.polarNote" to "当前处于极昼或极夜，无日出日落",
    "home.alarmTypeRegular" to "普通闹钟",
    "home.alarmTypeSunrise" to "日出闹钟",
    "home.alarmTypeSunset" to "日落闹钟",
    "home.inMinutes" to "{0}分钟后",
    "home.remainTime" to "还有{0}小时{1}分",
    "home.remainDays" to "还有{0}天",
    "home.nextAlarmDetail" to "{0} · {1} · {2}",
    "home.deleted" to "已删除",
    "home.deleteFailed" to "删除失败，请重试",
    "home.needPrivacy" to "请先同意隐私政策后再使用定位",
    "home.locateFailed" to "定位失败，请检查位置权限或到位置页手动选择",
    "home.locatedTo" to "已定位到 {0}",
    "home.weekSun" to "周日",
    "home.weekMon" to "周一",
    "home.weekTue" to "周二",
    "home.weekWed" to "周三",
    "home.weekThu" to "周四",
    "home.weekFri" to "周五",
    "home.weekSat" to "周六",
    "home.dateText" to "{0}月{1}日 {2}",
    "home.sunriseOffset" to "日出{0}",
    "home.sunsetOffset" to "日落{0}",
    "home.sameDay" to "当天",
    "home.offsetAfter" to "后{0}分钟",
    "home.offsetBefore" to "前{0}分钟",
    "home.setLocationHint" to "点击位置设置",
    "home.nextAlarm" to "下一个闹钟",
    "home.myAlarms" to "我的闹钟",
    "home.noAlarm" to "暂无闹钟，点击 + 添加",
    "home.sunToday" to "今日太阳",
    "home.daylight" to "白昼 {0}",
    "home.sunrise" to "日出",
    "home.sunset" to "日落",
    "edit.offsetZero" to "准时",
    "edit.offsetAfter" to "后 {0} 分钟",
    "edit.offsetBefore" to "前 {0} 分钟",
    "edit.newTitle" to "新建闹钟",
    "edit.title" to "编辑闹钟",
    "edit.typeSection" to "闹钟类型",
    "edit.typeRegular" to "普通闹钟",
    "edit.relSunrise" to "相对于日出",
    "edit.relSunset" to "相对于日落",
    "edit.advance" to "提前",
    "edit.delay" to "延后",
    "edit.repeat" to "重复",
    "edit.labelSection" to "标签",
    "edit.labelPlaceholder" to "给闹钟起个名字",
    "edit.soundSection" to "铃声",
    "edit.sound" to "铃声",
    "edit.vibrate" to "振动",
    "edit.saveButton" to "保存闹钟",
    "sound.default" to "默认铃声",
    "sound.defaultDesc" to "系统默认闹钟铃声",
    "sound.system" to "系统铃声",
    "sound.systemDesc" to "从系统铃声库中选择",
    "sound.localMusic" to "本地音乐",
    "sound.localMusicDesc" to "从手机文件中选择音乐",
    "sound.dialogTitle" to "选择铃声",
    "sound.current" to "当前: {0}",
    "toast.musicSelected" to "已选择 {0}",
    "toast.pickerUnavailable" to "文件选择器不可用",
    "toast.addedWithWarning" to "已添加，但{0}",
    "toast.savedWithWarning" to "已保存，但{0}",
    "toast.added" to "已添加",
    "toast.saved" to "已保存",
    "toast.saveFailed" to "保存失败: {0}",
    "toast.ringLibraryUnavailable" to "系统不开放铃声库，请用「本地音乐」选择",
    "privacy.title" to "用户协议与隐私政策",
    "privacy.subtitle" to "请在使用「日出闹钟」前阅读并同意以下内容",
    "privacy.sectionCollect" to "一、我们收集哪些信息",
    "privacy.bodyCollect" to "· 位置信息（粗略 / 精确）：仅在你点击「定位」并授权后获取，用于在本机离线计算当地日出、日落时间。\n· 闹钟设置：你创建的时间、铃声、重复规则。",
    "privacy.sectionStorage" to "二、信息如何存储",
    "privacy.bodyStorage" to "以上信息全部保存在你的设备本地，不上传服务器。本应用没有账号体系，我们无法远程读取你的数据；卸载应用即全部删除。",
    "privacy.sectionPermission" to "三、权限用途",
    "privacy.bodyPermission" to "· 位置权限：计算日出日落时间，拒绝后可使用手动选择的城市。\n· 通知权限：闹钟到点时响铃提醒。\n· 网络权限：可选，仅用于在线校准日出日落数据。",
    "privacy.sectionThirdParty" to "四、第三方共享",
    "privacy.bodyThirdParty" to "本应用不接入广告、统计、推送类 SDK，不会向任何第三方共享或转让你的信息。",
    "privacy.footnote" to "点击「同意并继续」即表示你已阅读并同意上述内容。",
    "privacy.reject" to "不同意并退出",
    "privacy.agree" to "同意并继续",
    "location.title" to "位置设置",
    "location.current" to "当前位置",
    "location.locatingText" to "定位中…",
    "location.located" to "已定位",
    "location.unknown" to "未知位置",
    "location.relocate" to "重新定位",
    "location.autoLocate" to "自动定位",
    "location.autoLocateDesc" to "根据GPS自动更新位置",
    "location.manualSelect" to "手动选择位置",
    "location.searchPlaceholder" to "搜索城市、地区",
    "location.searchButton" to "搜索",
    "location.searching" to "搜索中…",
    "location.savedPlaces" to "已保存位置",
    "location.noSaved" to "暂无保存的位置",
    "location.manualEntry" to "手动输入经纬度",
    "location.inUse" to "当前使用",
    "location.setAsCurrent" to "设为当前",
    "location.manualNameLabel" to "位置名称（可选）",
    "location.manualNameHint" to "如：我的家乡",
    "location.latLabel" to "纬度（-90 ~ 90）",
    "location.latHint" to "如：39.9042",
    "location.lonLabel" to "经度（-180 ~ 180）",
    "location.lonHint" to "如：116.4074",
    "location.errLatFormat" to "纬度格式不正确",
    "location.errLatRange" to "纬度范围为 -90 ~ 90",
    "location.errLonFormat" to "经度格式不正确",
    "location.errLonRange" to "经度范围为 -180 ~ 180",
    "location.customPlace" to "自定义位置",
    "location.locateFailed" to "定位失败，请检查位置权限",
    "location.locateDenied" to "位置权限未开启，请到系统设置开启；也可直接选城市",
    "location.locateNoFix" to "暂时取不到位置，请到室外重试或直接选城市",
    "location.locateSuccess" to "定位成功：{0}",
    "location.searchEmpty" to "请输入搜索内容",
    "location.searchNoResult" to "未找到「{0}」，换个关键词试试",
    "location.searchFailed" to "搜索失败，请稍后再试",
    "location.switched" to "已切换到 {0}",
    "location.saveFailed" to "保存位置失败",
    "location.failed" to "失败",
    "settings.title" to "设置",
    "settings.appearance" to "外观",
    "settings.themeDark" to "深色模式",
    "settings.themeDarkDesc" to "暗色背景，夜间使用护眼",
    "settings.themeLight" to "浅色模式",
    "settings.themeLightDesc" to "明亮背景，白天使用清晰",
    "settings.themeSystem" to "跟随系统",
    "settings.themeSystemDesc" to "自动匹配系统深浅色设置",
    "settings.about" to "关于",
    "settings.version" to "版本",
    "settings.appName" to "应用名称",
    "settings.algorithm" to "日出日落算法",
    "settings.algorithmValue" to "NOAA + 在线校准",
    "settings.tipEdit" to "提示：长按闹钟卡片可以编辑闹钟",
    "settings.language" to "语言",
    "settings.langSystem" to "跟随系统",
    "settings.langSystemDesc" to "与系统语言保持一致",
    "settings.langZh" to "简体中文",
    "settings.langZhDesc" to "界面显示为简体中文",
    "settings.langEn" to "English",
    "settings.langEnDesc" to "界面显示为英文",
    "notify.permDisabled" to "未开启通知权限",
    "notify.permRequestFailed" to "请求通知授权失败({0})",
    "notify.missed" to "闹钟已错过",
    "notify.snoozeContent" to "稍后提醒 {0} 分钟",
    "notify.alarmPublishFailed" to "闹钟发布失败({0})",
    "notify.reminderPublishFailed" to "提醒发布失败({0})",
    "notify.sunriseAlarm" to "日出闹钟",
    "notify.sunsetAlarm" to "日落闹钟"
)

// ---------------------------------------------------------------------------
// 英文词典
// ---------------------------------------------------------------------------
private val EN: Map<String, String> = mapOf(
    "common.alarm" to "Alarm",
    "common.location" to "Location",
    "common.settings" to "Settings",
    "common.save" to "Save",
    "common.add" to "Add",
    "common.delete" to "Delete",
    "common.close" to "Close",
    "common.cancel" to "Cancel",
    "common.confirm" to "OK",
    "common.agree" to "Agree",
    "common.decline" to "Decline",
    "common.snooze" to "Snooze",
    "common.closeAlarm" to "Dismiss",
    "common.locating" to "Locating…",
    "common.appName" to "Sunrise Alarm",
    "common.sunrise" to "Sunrise",
    "common.sunset" to "Sunset",
    "common.am" to "AM",
    "common.pm" to "PM",
    "common.opFailed" to "Operation failed ({0})",
    "common.saveFailed" to "Save failed ({0})",
    "common.deleteFailed" to "Delete failed ({0})",
    "common.durationHM" to "{0}h {1}m",
    "time.am" to "AM",
    "time.pm" to "PM",
    "alarm.dayMon" to "Mon",
    "alarm.dayTue" to "Tue",
    "alarm.dayWed" to "Wed",
    "alarm.dayThu" to "Thu",
    "alarm.dayFri" to "Fri",
    "alarm.daySat" to "Sat",
    "alarm.daySun" to "Sun",
    "alarm.daySeparator" to ", ",
    "alarm.repeatEveryDay" to "Every day",
    "alarm.repeatWeekdays" to "Weekdays",
    "alarm.repeatOnce" to "Once",
    "alarm.sunrise" to "sunrise",
    "alarm.sunset" to "sunset",
    "alarm.offsetAfter" to "{1} min after {0}",
    "alarm.offsetBefore" to "{1} min before {0}",
    "ring.systemDefault" to "System default",
    "ring.custom" to "Custom",
    "ring.dawn" to "Dawn",
    "ring.warmSun" to "Warm sun",
    "ring.breeze" to "Breeze",
    "ring.birds" to "Birdsong",
    "ring.ocean" to "Ocean waves",
    "ring.chime" to "Gentle chime",
    "ring.ringing" to "Alarm ringing",
    "ring.snoozeButton" to "Snooze ({0} min)",
    "widget.durationHour" to "{0}h",
    "widget.durationHourMin" to "{0}h {1}m",
    "widget.polar" to "Polar day / night",
    "widget.daylight" to "Daylight",
    "home.notifyOff" to "Notifications are off, so alarms may not ring",
    "home.timeSourceOffline" to "Offline",
    "home.timeSourceOnline" to "Observatory",
    "home.polarNote" to "Polar day or night right now, so no sunrise or sunset",
    "home.alarmTypeRegular" to "Regular alarm",
    "home.alarmTypeSunrise" to "Sunrise alarm",
    "home.alarmTypeSunset" to "Sunset alarm",
    "home.inMinutes" to "in {0} min",
    "home.remainTime" to "in {0}h {1}m",
    "home.remainDays" to "in {0} days",
    "home.nextAlarmDetail" to "{0} · {1} · {2}",
    "home.deleted" to "Deleted",
    "home.deleteFailed" to "Couldn't delete, please try again",
    "home.needPrivacy" to "Please accept the privacy policy before using location",
    "home.locateFailed" to "Couldn't get your location. Check location permission, or pick a city on the Location page",
    "home.locatedTo" to "Located: {0}",
    "home.weekSun" to "Sun",
    "home.weekMon" to "Mon",
    "home.weekTue" to "Tue",
    "home.weekWed" to "Wed",
    "home.weekThu" to "Thu",
    "home.weekFri" to "Fri",
    "home.weekSat" to "Sat",
    "home.dateText" to "{2}, {0}/{1}",
    "home.sunriseOffset" to "{0} sunrise",
    "home.sunsetOffset" to "{0} sunset",
    "home.sameDay" to "same day",
    "home.offsetAfter" to "{0} min after",
    "home.offsetBefore" to "{0} min before",
    "home.setLocationHint" to "Tap to set location",
    "home.nextAlarm" to "Next alarm",
    "home.myAlarms" to "My alarms",
    "home.noAlarm" to "No alarms yet, tap + to add one",
    "home.sunToday" to "Today's sun",
    "home.daylight" to "Daylight {0}",
    "home.sunrise" to "Sunrise",
    "home.sunset" to "Sunset",
    "edit.offsetZero" to "On time",
    "edit.offsetAfter" to "{0} min after",
    "edit.offsetBefore" to "{0} min before",
    "edit.newTitle" to "New alarm",
    "edit.title" to "Edit alarm",
    "edit.typeSection" to "Alarm type",
    "edit.typeRegular" to "Regular",
    "edit.relSunrise" to "Relative to sunrise",
    "edit.relSunset" to "Relative to sunset",
    "edit.advance" to "Earlier",
    "edit.delay" to "Later",
    "edit.repeat" to "Repeat",
    "edit.labelSection" to "Label",
    "edit.labelPlaceholder" to "Name this alarm",
    "edit.soundSection" to "Sound",
    "edit.sound" to "Sound",
    "edit.vibrate" to "Vibrate",
    "edit.saveButton" to "Save alarm",
    "sound.default" to "Default sound",
    "sound.defaultDesc" to "The system default alarm sound",
    "sound.system" to "System sounds",
    "sound.systemDesc" to "Pick from the system ringtone library",
    "sound.localMusic" to "Local music",
    "sound.localMusicDesc" to "Pick a track from your device",
    "sound.dialogTitle" to "Choose a sound",
    "sound.current" to "Current: {0}",
    "toast.musicSelected" to "Selected {0}",
    "toast.pickerUnavailable" to "The file picker is unavailable",
    "toast.addedWithWarning" to "Added, but {0}",
    "toast.savedWithWarning" to "Saved, but {0}",
    "toast.added" to "Added",
    "toast.saved" to "Saved",
    "toast.saveFailed" to "Save failed: {0}",
    "toast.ringLibraryUnavailable" to "The system ringtone library isn't available, use Local music instead",
    "privacy.title" to "Terms & Privacy Policy",
    "privacy.subtitle" to "Please read and agree before using Sunrise Alarm",
    "privacy.sectionCollect" to "1. What we collect",
    "privacy.bodyCollect" to "· Location (approximate or precise): read only after you tap Locate and grant permission, used to compute local sunrise and sunset times offline on this device.\n· Alarm settings: the times, sounds and repeat rules you create.",
    "privacy.sectionStorage" to "2. How we store it",
    "privacy.bodyStorage" to "All of it stays on your device and is never uploaded. There are no accounts, so we cannot read your data remotely. Uninstalling the app deletes everything.",
    "privacy.sectionPermission" to "3. Why we ask for permissions",
    "privacy.bodyPermission" to "· Location: to compute sunrise and sunset. If declined, you can still pick a city manually.\n· Notifications: to ring when an alarm is due.\n· Network: optional, used only to calibrate sunrise and sunset data online.",
    "privacy.sectionThirdParty" to "4. Third-party sharing",
    "privacy.bodyThirdParty" to "The app bundles no ads, analytics or push SDKs, and never shares or transfers your information to any third party.",
    "privacy.footnote" to "By tapping Agree and continue you confirm you have read and accepted the above.",
    "privacy.reject" to "Decline and exit",
    "privacy.agree" to "Agree and continue",
    "location.title" to "Location",
    "location.current" to "Current location",
    "location.locatingText" to "Locating…",
    "location.located" to "Located",
    "location.unknown" to "Unknown location",
    "location.relocate" to "Locate again",
    "location.autoLocate" to "Auto locate",
    "location.autoLocateDesc" to "Update your location via GPS",
    "location.manualSelect" to "Choose a location manually",
    "location.searchPlaceholder" to "Search for a city or region",
    "location.searchButton" to "Search",
    "location.searching" to "Searching…",
    "location.savedPlaces" to "Saved locations",
    "location.noSaved" to "No saved locations",
    "location.manualEntry" to "Enter coordinates manually",
    "location.inUse" to "In use",
    "location.setAsCurrent" to "Set as current",
    "location.manualNameLabel" to "Location name (optional)",
    "location.manualNameHint" to "e.g. My hometown",
    "location.latLabel" to "Latitude (-90 to 90)",
    "location.latHint" to "e.g. 39.9042",
    "location.lonLabel" to "Longitude (-180 to 180)",
    "location.lonHint" to "e.g. 116.4074",
    "location.errLatFormat" to "Invalid latitude format",
    "location.errLatRange" to "Latitude must be between -90 and 90",
    "location.errLonFormat" to "Invalid longitude format",
    "location.errLonRange" to "Longitude must be between -180 and 180",
    "location.customPlace" to "Custom location",
    "location.locateFailed" to "Couldn't locate, please check location permission",
    "location.locateDenied" to "Location permission is off. Turn it on in Settings, or just pick a city",
    "location.locateNoFix" to "Couldn't get a fix right now. Try again outdoors, or just pick a city",
    "location.locateSuccess" to "Located: {0}",
    "location.searchEmpty" to "Please enter something to search",
    "location.searchNoResult" to "No match for “{0}”, try another keyword",
    "location.searchFailed" to "Search failed, please try again later",
    "location.switched" to "Switched to {0}",
    "location.saveFailed" to "Couldn't save the location",
    "location.failed" to "Failed",
    "settings.title" to "Settings",
    "settings.appearance" to "Appearance",
    "settings.themeDark" to "Dark",
    "settings.themeDarkDesc" to "Dark background, easier on the eyes at night",
    "settings.themeLight" to "Light",
    "settings.themeLightDesc" to "Bright background, clearer in daylight",
    "settings.themeSystem" to "Follow system",
    "settings.themeSystemDesc" to "Match the system light or dark setting",
    "settings.about" to "About",
    "settings.version" to "Version",
    "settings.appName" to "App name",
    "settings.algorithm" to "Sun algorithm",
    "settings.algorithmValue" to "NOAA + online calibration",
    "settings.tipEdit" to "Tip: long-press an alarm card to edit it",
    "settings.language" to "Language",
    "settings.langSystem" to "Follow system",
    "settings.langSystemDesc" to "Match the system language",
    "settings.langZh" to "简体中文",
    "settings.langZhDesc" to "Show the app in Simplified Chinese",
    "settings.langEn" to "English",
    "settings.langEnDesc" to "Show the app in English",
    "notify.permDisabled" to "Notifications are turned off",
    "notify.permRequestFailed" to "Couldn't request notification permission ({0})",
    "notify.missed" to "Missed alarm",
    "notify.snoozeContent" to "Snoozed for {0} min",
    "notify.alarmPublishFailed" to "Couldn't publish the alarm ({0})",
    "notify.reminderPublishFailed" to "Couldn't publish the reminder ({0})",
    "notify.sunriseAlarm" to "Sunrise alarm",
    "notify.sunsetAlarm" to "Sunset alarm"
)
