# 日出日落闹钟 · HarmonyOS 版

用 ArkTS / ArkUI 重写的日出日落闹钟。纯本地工具应用：按 NOAA 天文算法离线计算当地日出日落时间，
把闹钟定在日出前 / 日落后，或当作普通闹钟使用。

- 当前版本：**1.1.1（versionCode 1000007）**
- 支持设备：**手机 / 平板**（HarmonyOS 5.1 / API 18 及以上）
- 发布区域：全球（界面提供简体中文 + English）

> 1.1.1 起不再发布手表端，原 `wearable` 模块已从工程移除，包内只有一个 `entry` HAP。

## 目录结构

```
AppScope/                 应用级配置（包名、版本号、应用图标）
entry/
  src/main/ets/
    common/               主题、时间格式、多语言词条、隐私状态、日出日落算法
    data/                 关系型数据库（闹钟）、preferences（设置）
    model/                AlarmEntity 闹钟实体
    pages/                首页框架（底部三 Tab）、编辑页、响铃页
    views/                首页 / 位置页 / 设置页
    service/              代理提醒、定位、天文台在线校准
    widget/               桌面服务卡片
    entryability/         UIAbility
    entryformability/     卡片 ExtensionAbility
    ringability/          全屏响铃 Ability
  src/main/resources/     zh_CN / en_US 资源（应用名、权限理由等系统直接读取的文案）
build-profile.json5       构建配置（开源版已脱敏，不含签名）
```

## 构建

需要 DevEco Studio（含 HarmonyOS SDK 与 hvigor）。命令行构建：

```bash
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco Studio/sdk"
"<DevEco>/tools/node/node.exe" "<DevEco>/tools/hvigor/bin/hvigorw.js" \
  --mode project -p product=default assembleApp --no-daemon
```

产物在 `build/outputs/default/*.app`。

**注意**：不设 `DEVECO_SDK_HOME` 会报 `00303217`；在 WorkBuddy 一类注入了 `NODE_OPTIONS` 的
环境里，还要加 `env -u NODE_OPTIONS`，否则 hvigor 的子进程会因为注入的 shim 启动失败。

## 签名

仓库里的 `build-profile.json5` **不含签名配置**，证书与口令属于开发者私有材料，绝不入库。
本地打包前在 `app` 下补回 `signingConfigs`，并在 `products` 里加 `"signingConfig": "default"`，
格式见该文件顶部注释。

## 多语言

界面文案没有走 `string.json`，而是集中在内嵌词条表里：

- `entry/src/main/ets/common/I18n.ets` —— 中英两张 `Map<string, string>`，约 200 条
- 用法 `t('home.noAlarm')`；带变量时 `t('home.remainTime', [h, m])`，词条里写 `{0}` `{1}`
- 缺 key 时回落成 key 本身，不会崩、不会白屏
- 语言优先级：设置页手动选择 → 系统语言（`zh*` 为中文，其余英文）

`resources/` 下的 `string.json` 只保留系统直接读取的文案（应用名、权限申请理由等），
仍需按 `zh_CN` / `en_US` 各维护一份。

加新语种时，在 `I18n.ets` 里加一张 `Map` 并在 `Locale.isZh()` 的分支里接上即可。

## 几个平台坑（踩过，记下来）

| 现象 | 原因与解法 |
| --- | --- |
| 权限明明开了却提示「定位失败」 | `ohos.permission.LOCATION` 与 `APPROXIMATELY_LOCATION` 同属一个权限组，**不能放在一次 `requestPermissionsFromUser` 里申请**，否则返回非 0。拆成两次单独申请，任一授予即可用。 |
| 到点只收到「已错过」通知、不响铃 | 代理提醒的 `maxScreenWantAgent` 指向的 Ability 拉起失败时，系统只发 `expiredContent`。改用系统通知 + 震动更稳。 |
| 改了闹钟保存返回，界面没变化 | `ForEach` 的 key 必须覆盖所有可编辑字段（type / repeatDays / label / offset），否则会复用旧组件。 |
| 闹钟多了向下滑显示不全 | 外层 `Scroll` 里嵌的 `List` 高度不能硬编码。用 `onAreaChange` 实测卡片高度再乘项数，并关掉裁切。 |
| 切英文后错误提示变绿 | 不要用 `message.indexOf('失败')` 判断错误态，那是语言相关的；用独立布尔标记。 |

## 数据

- 闹钟：`relationalStore`（表 `alarm`）
- 设置与隐私同意状态：`preferences`（`sunrise_settings` / `sunrise_privacy`）
- 无账号体系，所有数据只存在本机，不上传服务器

## 免责

日出日落时间为天文算法估算值，受地形、天气、海拔影响会有数分钟偏差，不作为航海、航空等专业用途。
