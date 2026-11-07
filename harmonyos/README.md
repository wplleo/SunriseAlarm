# 晨光闹钟 (SunriseAlarm) — HarmonyOS 版

基于 NOAA 天文算法**离线**计算日出日落的闹钟应用。`com.sunrise.alarm`，当前版本 **1.1.0 (1000006)**。

同一个 app 包内含两个 HAP，支持 **手机 / 平板 / 智能手表**（HUAWEI WATCH 5 等 HarmonyOS 5.1 穿戴设备）：

| 模块 | deviceTypes | 说明 |
|---|---|---|
| `entry` | phone, tablet | 主应用：闹钟、位置、设置、日出日落服务卡片 |
| `wearable` | wearable | 手表应用：抬腕看今日日出日落、表上直接建闹钟、到点震动唤醒 |

> 仓库根目录是 Android 版（Kotlin / Jetpack Compose），本目录是 HarmonyOS 版。NOAA 算法层两端共用同一套逻辑。

## 功能

- **日出 / 日落闹钟**：按当天实际日出日落时间动态触发，可提前或延后 0–120 分钟；每天都不同，所以每次响铃后重新计算并续排下一次
- **普通闹钟**：固定时刻 + 七日重复
- **位置**：GPS 自动定位、城市搜索、手动经纬度（手表端精简为常用城市点选）
- **代理提醒**：`reminderAgentManager` 系统级提醒，杀掉进程也能响；穿戴设备无管控限制，手机/平板需申请开放能力
- **服务卡片**：桌面 2×2「日出日落」卡片，不打开应用即可看时间与昼长
- **暗色暖橙主题**：`#161618` / `#FF8C42`，手表端用纯黑 OLED 底色

## 技术栈

ArkTS + ArkUI（Stage 模型）、relationalStore（手机端闹钟库）、preferences（轻量设置 / 手表端闹钟）、
reminderAgentManager、geoLocationManager、FormExtensionAbility、vibrator。

- `compileSdkVersion 26.0.0` / `targetSdkVersion 26.0.0`
- **`compatibleSdkVersion 5.1.0(18)`** —— 手表首次支持智能穿戴开发就是 API 18，写高了好手表装不上。
  代价是手机端也能装到 API 18–25 的老设备，因此超过 18 的 API 一律用 `canIUse` 保护（定位、代理提醒已做）。

## 目录结构

```
harmonyos/
├── AppScope/                 # bundleName、版本、应用图标
├── entry/src/main/ets/
│   ├── common/               # NOAA 算法、时间格式、主题、隐私同意
│   ├── data/                 # AlarmRepository(relationalStore) / SettingsStore
│   ├── model/                # AlarmEntity（与 Android 版字段一致）
│   ├── service/              # LocationService / ReminderService / SunApiService
│   ├── pages/                # Index / AlarmEditPage / RingPage
│   ├── views/                # HomeView / LocationView / SettingsView
│   ├── widget/pages/         # WidgetCard（服务卡片）
│   ├── entryability/  ringability/
│   └── entryformability/     # EntryFormAbility
├── wearable/src/main/ets/    # 手表端，算法层从 entry 原样复用
│   ├── common/WatchTheme.ets
│   ├── data/AlarmStore.ets         # preferences 存 JSON，冷启动更快
│   ├── service/ReminderService.ets # 全屏页不支持时自动降级
│   └── pages/                      # Index / AlarmEditPage / LocationPage / RingPage
├── icon/                     # 应用市场用 1024×1024 图标
└── tools/verify-sunrise.ts   # 日出算法校验脚本
```

## 圆屏布局约束（改手表 UI 前先读）

WATCH 5 为 **233×233 vp 圆屏**（r = 116.5）。距顶 y 处的可用宽度：

```
W(y) = 2 × √(r² − (r − y)²)
```

y=18→124、y=30→156、y=44→182、圆心→233。**贴顶、贴底、满宽的布局一定会被圆弧切角**。
所以手表端内容一律垂直居中或留 40vp+ 上下内边距；底部按钮宽度收窄到 140；
返回按钮放在 `(40,16)` 而不是左上角 `(8,8)`（后者在圆外，点不到）。
列表用 `ArcList` / `ArcListItem`（API 18 起），必须显式 `import { ArcList, ArcListItem } from '@ohos.arkui.ArcList'`，
`.space()` 是属性方法且参数是 `LengthMetrics`，不是构造参数。

## 编译

DevEco Studio 直接打开本目录即可。命令行（已在本机跑通）：

```bash
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco Studio/sdk"
node "$DEVECO_SDK_HOME/../tools/node/node.exe" \
  "$DEVECO_SDK_HOME/../tools/hvigor/bin/hvigorw.js" \
  --mode project -p product=default assembleApp --no-daemon
```

产物在 `build/outputs/default/SunriseAlarmHarmony-default-signed.app`，
内含 `entry-default.hap` + `wearable-default.hap`。不设 `DEVECO_SDK_HOME` 会报 `00303217 Configuration Error`。

## 签名配置（clone 后必读）

**证书和口令不在这个仓库里**。`build-profile.json5` 是脱敏版，`signingConfigs` 整段被移除，
所以直接打包只会得到 unsigned 包。本地要出签名包，请：

1. 用 DevEco Studio 的 *File > Project Structure > Signing Configs* 自动生成签名，
   或把自己的证书放进 `signature/`（已被 `.gitignore` 排除）；
2. 在 `build-profile.json5` 的 `app` 下补回 `signingConfigs`，并在 `products[0]` 里加 `"signingConfig": "default"`；
3. 别名、加密口令、`.cer` / `.p7b` / `.p12` 路径按自己账号填。

模板片段已写在 `build-profile.json5` 顶部注释里。

## 与 Android 版的关键差异

| 能力 | Android | HarmonyOS |
|---|---|---|
| 闹钟调度 | AlarmManager + BroadcastReceiver | reminderAgentManager（代理提醒） |
| 定位 | Google Play Services Location | geoLocationManager |
| 存储 | Room | relationalStore / preferences |
| UI | Jetpack Compose | ArkUI（手表用 ArcList） |
| 桌面 | App Widget | FormExtensionAbility 服务卡片 |

## 备注

- `build-output/` 里保留的是**早期 API 12 版本**的演示包，不是当前 1.1.0 的包，别拿去装。
- 手表震动强度、代理提醒到点、圆屏实际裁切等仍需在真机上复验（开发环境无穿戴设备）。
