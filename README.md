# 晨光闹钟 (SunriseAlarm)

基于 NOAA 天文算法离线计算日出日落的智能闹钟。**本仓库同时收录两个平台的实现**：

| 平台 | 目录 | 说明 |
|------|------|------|
| Android | 仓库根目录 | Kotlin / Jetpack Compose，见下文 |
| HarmonyOS | [`harmonyos/`](./harmonyos/) | ArkTS / ArkUI，手机 + 平板 + 智能手表（WATCH 5） |

以下为 **Android 版**文档。

## 功能

- **日出/日落闹钟**：根据当前位置自动计算日出日落时间，支持提前/延后偏移
- **自动定位**：GPS 自动获取当前位置，实时更新日出日落时间
- **手动位置**：支持搜索城市或手动输入经纬度
- **普通闹钟**：也可作为传统闹钟使用，设定固定时间
- **离线计算**：日出日落时间基于 NOAA 算法本地计算，无需网络

## 技术栈

- **语言**：Kotlin
- **UI**：Jetpack Compose + Material3
- **架构**：MVVM (ViewModel + StateFlow)
- **数据库**：Room
- **导航**：Navigation Compose
- **定位**：Google Play Services Location
- **闹钟调度**：AlarmManager + 前台服务
- **最低 SDK**：Android 8.0 (API 26)
- **目标 SDK**：Android 14 (API 34)

## 项目结构

```
SunriseAlarm/
├── app/
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/sunrise/alarm/
│       │   ├── MainActivity.kt              # 入口 Activity
│       │   ├── SunriseAlarmApp.kt           # Application 类
│       │   ├── data/                         # 数据层
│       │   │   ├── AlarmEntity.kt            # 闹钟实体 + 类型枚举
│       │   │   ├── AlarmDao.kt               # Room DAO
│       │   │   ├── AlarmDatabase.kt          # Room 数据库
│       │   │   ├── AlarmRepository.kt        # 仓库
│       │   │   └── LocationPreferences.kt    # 位置偏好存储
│       │   ├── service/                      # 服务层
│       │   │   ├── LocationService.kt        # GPS 定位服务
│       │   │   ├── AlarmReceiver.kt          # 闹钟广播接收器
│       │   │   ├── AlarmRingService.kt       # 响铃前台服务
│       │   │   └── BootReceiver.kt           # 开机自启
│       │   ├── util/                         # 工具
│       │   │   ├── SunriseSunsetCalculator.kt # NOAA 日出日落算法
│       │   │   └── AlarmScheduler.kt         # 闹钟调度器
│       │   └── ui/                           # UI 层
│       │       ├── theme/                    # 主题（暗色暖橙）
│       │       ├── navigation/               # 导航
│       │       ├── home/                     # 主页（闹钟列表）
│       │       ├── addalarm/                 # 新建/编辑闹钟
│       │       └── location/                 # 位置设置
│       └── res/                              # 资源
│           ├── values/                       # 字符串、颜色、主题
│           ├── drawable/                     # 图标
│           └── xml/                          # 备份规则
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
└── gradle/wrapper/gradle-wrapper.properties
```

## 构建方法

### 方法一：Android Studio（推荐）

1. 打开 Android Studio
2. 选择 `File > Open`，选择 `SunriseAlarm` 目录
3. 等待 Gradle 同步完成
4. 点击 `Run` 按钮编译并运行

### 方法二：命令行

需要先安装 Gradle 8.5+ 或生成 Gradle Wrapper：

```bash
# 如果已安装 Gradle
cd SunriseAlarm
gradle wrapper
./gradlew assembleDebug

# APK 输出路径
# app/build/outputs/apk/debug/app-debug.apk
```

## 权限说明

| 权限 | 用途 |
|------|------|
| `SCHEDULE_EXACT_ALARM` | 精确闹钟调度 |
| `USE_EXACT_ALARM` | Android 13+ 精确闹钟 |
| `WAKE_LOCK` | 唤醒设备 |
| `RECEIVE_BOOT_COMPLETED` | 开机后恢复闹钟 |
| `VIBRATE` | 闹钟振动 |
| `POST_NOTIFICATIONS` | 闹钟通知 |
| `FOREGROUND_SERVICE` | 响铃前台服务 |
| `FOREGROUND_SERVICE_ALARM` | Android 14+ 闹钟服务类型 |
| `ACCESS_FINE_LOCATION` | GPS 精确定位 |
| `ACCESS_COARSE_LOCATION` | 粗略定位 |

## 设计稿

设计稿地址：https://ardot.tencent.com/file/708996051042477

主题色：暗色背景 `#161618`，暖橙强调色 `#FF8C42`，日出日落渐变。

## HarmonyOS 版

见 [`harmonyos/README.md`](./harmonyos/README.md)。当前 1.1.0，同一个 app 包内包含
`entry`（phone / tablet）与 `wearable`（智能手表）两个 HAP，最低兼容 HarmonyOS 5.1 (API 18)。
NOAA 算法、闹钟实体、时间格式等纯逻辑层与 Android 版保持一致，平台层（代理提醒、定位、存储、服务卡片）重写。

> 该目录的 `build-profile.json5` 是脱敏版，不含签名证书与口令；本地打包需自行配置签名。
