/**
 * 设置页内容 —— 与 Android 版 SettingsScreen.kt 一一对应
 *
 * 结构：
 *  1. 标题「设置」（20sp Semibold，左对齐，没有返回按钮——安卓是底部 Tab 切换）
 *  2. 「外观」卡片（可折叠）：标题行显示当前主题名 + 箭头，展开后是
 *     深色 / 浅色 / 跟随系统 三行（圆形图标 + 右侧实心圆点指示器）
 *  3. 「语言」卡片（可折叠）：结构同外观，展开后是 跟随系统 / 简体中文 / English
 *  4. 「关于」卡片：版本 / 应用名称 / 日出日落算法 三行，纯展示不折叠
 *  5. 底部提示：长按闹钟卡片可以编辑闹钟
 *
 * 外观和语言默认收起 —— 这两项日常几乎不改，收起后整页只剩三行摘要，
 * 一眼能看全；收起状态在标题行右侧保留当前取值，不用展开也知道现在是什么。
 *
 * 注意：安卓端没有「24 小时制」「在线校准」「自动定位」这几个开关，
 * 移植时曾被额外加入，导致审核驳回（关闭开关后仍按 24 小时显示）。此处按安卓对齐删除。
 */
import { common, bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SettingsStore } from '../data/SettingsStore';
import { ThemeManager, ThemeMode, ThemeColors, DARK_COLORS } from '../common/AppTheme';
import { t, Locale } from '../common/I18n';

@Component
export struct SettingsView {
  /** 每次切到本页由 Index 递增，用于刷新主题等状态 */
  @Prop @Watch('onTick') tick: number = 0;

  @State themeMode: ThemeMode = ThemeMode.DARK;
  /** 界面语言：'system' | 'zh' | 'en' */
  @State language: string = 'system';
  @State colors: ThemeColors = DARK_COLORS;
  /** 版本号，从应用信息读取 */
  @State appVersion: string = '1.0.0';
  /**
   * 「外观」/「语言」分组是否展开。默认收起，页面上只露一行摘要。
   *
   * 必须用 @StorageLink 而不是 @State：切换语言会把整个设置页重建一遍，
   * @State 会被重置 —— 表现为用户刚点完「简体中文」，语言分组立刻自己收起来了。
   * 挂在 AppStorage 上就能跨重建保留。
   */
  @StorageLink('settings.appearanceOpen') appearanceOpen: boolean = false;
  @StorageLink('settings.languageOpen') languageOpen: boolean = false;

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
    // 把已保存的语言偏好注入 Locale，冷启动第一帧就是对的
    this.language = SettingsStore.getLanguage();
    Locale.setOverride(this.language);
  }

  /**
   * 切换界面语言。
   * Locale 是全局静态状态，光改它 Web 层不会重绘 —— 这里再自增 AppStorage 上的
   * langVersion，Index 监听到之后会把三个 Tab 的 tick 全部 +1，
   * 各页面 reload() 一遍，文案随之重新取。
   */
  private async switchLanguage(value: string): Promise<void> {
    if (this.language === value) {
      return;
    }
    try {
      await SettingsStore.setLanguage(value);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[Settings] 保存语言偏好失败: ${e.code} ${e.message}`);
    }
    this.language = value;
    Locale.setOverride(value);
    const v: number = AppStorage.get<number>('langVersion') ?? 0;
    AppStorage.setOrCreate<number>('langVersion', v + 1);
  }

  /** 从 bundleManager 读版本号；versionName 需带 WITH_APPLICATION 标志才会填充 */
  private readVersion(): string {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      if (info.versionName.length > 0) {
        return info.versionName;
      }
      // 兜底：版本号来自包内 module.json，读不到就显示占位符，不写死版本
      return '—';
    } catch (e) {
      return '—';
    }
  }

  onTick(): void {
    this.themeMode = ThemeManager.getMode();
    this.colors = ThemeManager.colors(this.context);
  }

  /**
   * 分组收起后的摘要：当前选中的主题名。
   * 收起来不能把状态一起藏了 —— 用户不展开也得一眼看见现在是深色还是浅色。
   */
  private themeLabel(): string {
    if (this.themeMode === ThemeMode.LIGHT) {
      return t('settings.themeLight');
    }
    if (this.themeMode === ThemeMode.SYSTEM) {
      return t('settings.themeSystem');
    }
    return t('settings.themeDark');
  }

  /** 分组收起后的摘要：当前选中的语言名 */
  private langLabel(): string {
    if (this.language === 'zh') {
      return t('settings.langZh');
    }
    if (this.language === 'en') {
      return t('settings.langEn');
    }
    return t('settings.langSystem');
  }

  /** 折叠动画：高度变化交给 animateTo，箭头旋转自己带 .animation() */
  private toggleAppearance(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.appearanceOpen = !this.appearanceOpen;
    });
  }

  private toggleLanguage(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.languageOpen = !this.languageOpen;
    });
  }

  async switchTheme(mode: ThemeMode): Promise<void> {
    await ThemeManager.setMode(this.context, mode);
    this.themeMode = mode;
    this.colors = ThemeManager.colors(this.context);
    // 广播给 Index：底部导航条的颜色挂在它身上，不通知就会一直停在旧主题
    const v: number = AppStorage.get<number>('themeVersion') ?? 0;
    AppStorage.setOrCreate<number>('themeVersion', v + 1);
  }

  build() {
    Column() {
      // ---------- 标题栏（安卓没有返回按钮）----------
      Row() {
        Text(t('settings.title'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 56, bottom: 12 })

      Scroll() {
        Column({ space: 20 }) {
          // ---------- 外观（可折叠）----------
          // 标题行始终可见，右侧带当前选中的主题名 + 展开箭头；
          // 点标题行展开/收起下面的三个主题选项。
          Column() {
            Row() {
              Text(t('settings.appearance'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.text)
              Blank()
              Text(this.themeLabel())
                .fontSize(13)
                .fontColor(this.colors.textGray)
              Image($r('app.media.ic_chevron_down'))
                .width(18)
                .height(18)
                .fillColor(this.colors.textGray)
                .margin({ left: 6 })
                .rotate({ angle: this.appearanceOpen ? 180 : 0 })
                .animation({ duration: 220, curve: Curve.EaseInOut })
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .onClick(() => { this.toggleAppearance(); })

            if (this.appearanceOpen) {
              Column() {
                this.DividerLine()
                this.ThemeOption(t('settings.themeDark'), t('settings.themeDarkDesc'), ThemeMode.DARK,
                  $r('app.media.ic_moon'))
                this.DividerLine()
                this.ThemeOption(t('settings.themeLight'), t('settings.themeLightDesc'), ThemeMode.LIGHT,
                  $r('app.media.ic_sun'))
                this.DividerLine()
                this.ThemeOption(t('settings.themeSystem'), t('settings.themeSystemDesc'), ThemeMode.SYSTEM,
                  $r('app.media.ic_brightness'))
              }
              .width('100%')
            }
          }
          .width('100%')
          .backgroundColor(this.colors.card)
          .borderRadius(16)
          .clip(true)

          // ---------- 语言（可折叠）----------
          Column() {
            Row() {
              Text(t('settings.language'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.text)
              Blank()
              Text(this.langLabel())
                .fontSize(13)
                .fontColor(this.colors.textGray)
              Image($r('app.media.ic_chevron_down'))
                .width(18)
                .height(18)
                .fillColor(this.colors.textGray)
                .margin({ left: 6 })
                .rotate({ angle: this.languageOpen ? 180 : 0 })
                .animation({ duration: 220, curve: Curve.EaseInOut })
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .onClick(() => { this.toggleLanguage(); })

            if (this.languageOpen) {
              Column() {
                this.DividerLine()
                this.LangOption(t('settings.langSystem'), t('settings.langSystemDesc'), 'system')
                this.DividerLine()
                this.LangOption(t('settings.langZh'), t('settings.langZhDesc'), 'zh')
                this.DividerLine()
                this.LangOption(t('settings.langEn'), t('settings.langEnDesc'), 'en')
              }
              .width('100%')
            }
          }
          .width('100%')
          .backgroundColor(this.colors.card)
          .borderRadius(16)
          .clip(true)

          // ---------- 关于 ----------
          // 纯展示信息，不做折叠：标题行与上面两块保持同一种卡片样式，
          // 但不带箭头、不可点，避免让人以为展开还有隐藏内容。
          Column() {
            Row() {
              Text(t('settings.about'))
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.text)
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })

            Column() {
              this.DividerLine()
              this.InfoRow(t('settings.version'), this.appVersion)
              this.DividerLine()
              this.InfoRow(t('settings.appName'), t('common.appName'))
              this.DividerLine()
              this.InfoRow(t('settings.algorithm'), t('settings.algorithmValue'))
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor(this.colors.card)
          .borderRadius(16)
          .clip(true)

          // ---------- 提示 ----------
          Text(t('settings.tipEdit'))
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

  /**
   * 语言选项行：标题 + 说明 + 右侧选中圆点
   *
   * 左侧和外观行一样带圆形图标 —— 之前没有图标，这一组的文字比上下两组整体左移，
   * 三张卡片摞在一起时左边界对不齐，看着像没做完。
   */
  @Builder
  LangOption(title: string, subtitle: string, value: string) {
    Row() {
      Stack() {
        Circle({ width: 40, height: 40 }).fill(this.colors.cardHover)
        Image($r('app.media.ic_language'))
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

      Stack() {
        if (this.language === value) {
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
    .onClick(() => {
      this.switchLanguage(value).catch((err: BusinessError) => {
        console.warn(`[Settings] 切换语言失败: ${err.code} ${err.message}`);
      });
    })
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
