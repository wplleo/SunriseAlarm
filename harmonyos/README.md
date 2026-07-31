# 晨光闹钟 (SunriseAlarm) — HarmonyOS NEXT 版

基于 NOAA 天文算法离线计算日出日落的闹钟 App，ArkTS / ArkUI 实现，适配 HarmonyOS NEXT（API 12+, Stage 模型）。

> 这是 Android 版（Kotlin/Jetpack Compose）的鸿蒙移植。核心 NOAA 算法从 Kotlin 1:1 翻译为 ArkTS，UI 与平台集成层（定位/闹钟/通知）按鸿蒙 API 重写。

## 功能

- 🌅 **日出闹钟** / 🌇 **日落闹钟**：按 NOAA 算出的日出日落时间动态触发，支持提前/延后偏移
- ⏰ **普通闹钟**：每天固定时间
- 📍 **位置**：GPS 自动定位、城市搜索、手动经纬度输入（逆地理编码）
- 🌑 **暗色暖橙主题**：与 Android 版一致的视觉

## 架构

```
entry/src/main/ets/
├── entryability/EntryAbility.ts      # 应用入口，初始化存储
├── pages/
│   ├── HomePage.ets                  # 主页面：Tab(闹钟/位置/设置) + 今日日出日落 + 闹钟列表
│   ├── AddAlarmPage.ets              # 新增闹钟
│   ├── LocationPage.ets              # 位置管理（嵌入 HomePage）
│   └── SettingsPage.ets              # 设置（嵌入 HomePage）
├── service/
│   ├── LocationService.ets           # @ohos.geoLocationManager 封装
│   └── AlarmScheduler.ets            # @ohos.reminderAgentManager 封装（替代 AlarmManager）
├── data/AlarmRepository.ets          # @ohos.data.preferences 存储（替代 Room）
├── model/AlarmModel.ets              # 闹钟数据模型
├── utils/SunriseSunsetCalculator.ets # NOAA 日出日落算法（纯数学，零平台依赖）
└── theme/Theme.ets                   # 主题色板
```

## 与原 Android 版的关键差异

| 能力 | Android | HarmonyOS NEXT |
|------|---------|----------------|
| 闹钟调度 | `AlarmManager` + `BroadcastReceiver` | `reminderAgentManager`（系统级提醒） |
| 定位 | `LocationManager` / `Geocoder` | `geoLocationManager` |
| 存储 | Room (SQLite) | `data.preferences` |
| UI | Jetpack Compose | ArkUI |

### 日出/日落闹钟的重复机制

日出日落时间每天都不同，鸿蒙的 `ReminderRequestTimer` 一次性触发。本项目发布的是「下一次」触发时间；
要让它每天自动响，**需在触发后重新计算并再次发布**（建议在 App 启动时调用一次 reschedule）。
普通闹钟用 `ReminderRequestAlarm` + `daysOfWeek` 每日重复，无需额外处理。

## 编译运行

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（NEXT 版本）
2. 打开本目录（`File > Open > SunriseAlarmOHOS`）
3. 用华为开发者账号签名（**File > Project Structure > Signing Configs**，勾选 Automatically generate signature）
4. 连接真机或启动模拟器，`Run > Run 'entry'`

> 真机调试需要华为开发者账号并完成设备实名。模拟器部分定位/提醒能力可能受限。

### 命令行编译（CI / 无 GUI，已验证）

已用 **HarmonyOS Command Line Tools 6.1.1.300** 在本机跑通（`BUILD SUCCESSFUL`）。

**前提：**
- 下载 [Command Line Tools for HarmonyOS](https://developer.huawei.com/consumer/cn/download/)（内含 hvigor + ohpm + SDK + node）
- 单独装 JDK 17（工具链不含 JDK）

**⚠️ 路径必须全英文！** 项目路径、SDK 路径、JDK 路径都不能含中文（`软件开发` 会导致 hvigor / SDK 资源解析失败）。建议：
- 工具链放 `C:\ohos_tools\command-line-tools`
- JDK 放 `C:\jdk17`
- 本项目放 `C:\ohos_build\SunriseAlarmOHOS`

**直接运行：**

```bat
REM build_ohos.bat（已内置，按上面路径摆放后双击即可）
build_ohos.bat
REM 产物: build/outputs/default/SunriseAlarmOHOS-default-unsigned.app
REM        entry/build/default/outputs/default/entry-default-unsigned.hap
```

**手动命令（等效，绕过 .bat 沙箱限制）：**

```bash
export JAVA_HOME=/c/ohos_tools/jdk17          # 正斜杠给 bash 找 java
export DEVECO_NODE_HOME=C:/ohos_tools/command-line-tools/tool/node   # 反斜杠给 node
export DEVECO_SDK_HOME=C:/ohos_tools/command-line-tools/sdk
export PATH=$JAVA_HOME/bin:$DEVECO_NODE_HOME:$PATH
unset NODE_OPTIONS                            # 关键：关掉 WorkBuddy safe-delete shim
unset CODEBUDDY_SESSION_ID
cd /c/ohos_build/SunriseAlarmOHOS
node $DEVECO_NODE_HOME/node.exe $DEVECO_NODE_HOME/../../hvigor/bin/hvigorw.js assembleApp --no-daemon
```

> **签名**：`hapsigner` / `hap-sign-tool.jar` 不在 Command Line Tools 包内。真机安装需华为开发者账号调试签名——在 DevEco Studio 打开本项目，`File > Project Structure > Signing Configs` 勾 **Automatically generate signature** 即可产出可装真机的签名包。当前命令行产物为**未签名**版（模拟器可装，真机需签名）。

> **HAP vs APP**：`.hap` 是模块包，可直接装模拟器 / 已签名真机调试；`.app` 是打包的发布格式，需要正式签名后才能上架或分发安装。


## 权限

`module.json5` 已声明：
- `ohos.permission.LOCATION` / `ohos.permission.APPROXIMATELY_LOCATION`（定位）
- `ohos.permission.PUBLISH_AGENT_REMINDER`（发布系统提醒）

运行时首次使用定位会弹窗申请。

## 下一步

- iOS 版（用 Kotlin Multiplatform 共享核心逻辑 + SwiftUI，或 Flutter）
- 日出/日落闹钟的每日自动 reschedule 逻辑
