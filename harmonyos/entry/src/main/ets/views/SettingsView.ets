/**
 * 设置页内容 —— 与 Android 版 SettingsScreen.kt 一一对应
 *
 * 结构完全照搬安卓：
 *  1. 标题「设置」（20sp Semibold，左对齐，没有返回按钮——安卓是底部 Tab 切换）
 *  2. 「外观」：深色模式 / 浅色模式 / 跟随系统，带圆形图标 + 右侧实心圆点指示器
 *  3. 「关于」：版本 / 应用名称 / 日出日落算法 三行
 *  4. 底部提示：长按闹钟卡片可以编辑闹钟
 *
 * 注意：安卓端没有「24 小时制」「在线校准」「自动定位」这几个开关，
 * 移植时曾被额外加入，导致审核驳回（关闭开关后仍按 24 小时显示）。此处按安卓对齐删除。
 */
import { common, bundleManager } from '@kit.AbilityKit';
import { SettingsStore } from '../data/SettingsStore';
import { ThemeManager, ThemeMode, ThemeColors, DARK_COLORS } from '../common/AppTheme';

@Component
export struct SettingsView {
  /** 每次切到本页由 Index 递增，用于刷新主题等状态 */
  @Prop @Watch('onTick') tick: number = 0;

  @State themeMode: ThemeMode = ThemeMode.DARK;
  @State colors: ThemeColors = DARK_COLORS;
  /** 版本号，从应用信息读取 */
  @State appVersion: string = '1.0.0';

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    try {
      await SettingsStore.init(this.context);
      await ThemeManager.init(this.context);
    } catch (err) {
      console.warn('[Settings] 数据层初始化失败');
    }
    this.themeMode = ThemeManager.getMode();
    this.colors = ThemeManager.colors(this.context);
    this.appVersion = this.readVersion();
  }

  /** 从 bundleManager 读版本号，读不到就用默认值 */
  private readVersion(): string {
    try {
      const info: bundleManager.BundleInfo =
        bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return info.versionName.length > 0 ? info.versionName : '1.0.0';
    } catch (e) {
      return '1.0.0';
    }
  }

  onTick(): void {
    this.themeMode = ThemeManager.getMode();
    this.colors = ThemeManager.colors(this.context);
  }

  async switchTheme(mode: ThemeMode): Promise<void> {
    await ThemeManager.setMode(this.context, mode);
    this.themeMode = mode;
    this.colors = ThemeManager.colors(this.context);
  }

  build() {
    Column() {
      // ---------- 标题栏（安卓没有返回按钮）----------
      Row() {
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 56, bottom: 12 })

      Scroll() {
        Column({ space: 20 }) {
          // ---------- 外观 ----------
          Column() {
            Row() {
              Text('外观')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.textGray)
            }
            .width('100%')
            .padding({ bottom: 10 })

            Column() {
              this.ThemeOption('深色模式', '暗色背景，夜间使用护眼', ThemeMode.DARK, $r('app.media.ic_moon'))
              this.DividerLine()
              this.ThemeOption('浅色模式', '明亮背景，白天使用清晰', ThemeMode.LIGHT, $r('app.media.ic_sun'))
              this.DividerLine()
              this.ThemeOption('跟随系统', '自动匹配系统深浅色设置', ThemeMode.SYSTEM, $r('app.media.ic_brightness'))
            }
            .width('100%')
            .backgroundColor(this.colors.card)
            .borderRadius(16)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // ---------- 关于 ----------
          Column() {
            Row() {
              Text('关于')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.textGray)
            }
            .width('100%')
            .padding({ bottom: 10 })

            Column() {
              this.InfoRow('版本', this.appVersion)
              this.DividerLine()
              this.InfoRow('应用名称', '日出闹钟')
              this.DividerLine()
              this.InfoRow('日出日落算法', 'NOAA + 在线校准')
            }
            .width('100%')
            .backgroundColor(this.colors.card)
            .borderRadius(16)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // ---------- 提示 ----------
          Text('提示：长按闹钟卡片可以编辑闹钟')
            .fontSize(13)
            .fontColor(this.colors.textGray)
            .width('100%')
            .padding({ left: 4 })

          Row().height(20)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bg)
  }

  /**
   * 主题选项行：左侧圆形底 + 图标，中间标题/副标题，右侧实心圆点指示器
   * 对齐 Android ThemeModeOption
   */
  @Builder
  ThemeOption(title: string, subtitle: string, mode: ThemeMode, icon: Resource) {
    Row() {
      Stack() {
        Circle({ width: 40, height: 40 }).fill(this.colors.cardHover)
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(this.colors.accent)
      }
      .width(40)
      .height(40)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
        Text(subtitle)
          .fontSize(12)
          .fontColor(this.colors.textGray)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
      .layoutWeight(1)

      // 选中：橙色圆底 + 白色小圆点；未选中：透明
      Stack() {
        if (this.themeMode === mode) {
          Circle({ width: 20, height: 20 }).fill(this.colors.accent)
          Circle({ width: 8, height: 8 }).fill('#FFFFFF')
        } else {
          Circle({ width: 18, height: 18 }).fill(Color.Transparent)
        }
      }
      .width(20)
      .height(20)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => { this.switchTheme(mode); })
  }

  /** 关于信息行：图标 + 标题 + 右侧值 */
  @Builder
  InfoRow(title: string, value: string) {
    Row() {
      Stack() {
        Circle({ width: 40, height: 40 }).fill(this.colors.cardHover)
        Image($r('app.media.ic_info'))
          .width(20)
          .height(20)
          .fillColor(this.colors.accent)
      }
      .width(40)
      .height(40)

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.colors.text)
        .margin({ left: 14 })
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor(this.colors.textGray)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  DividerLine() {
    Row()
      .width('100%')
      .height(0.5)
      .backgroundColor(this.colors.cardHover)
      .margin({ left: 16, right: 16 })
  }
}
