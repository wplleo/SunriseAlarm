/**
 * 主框架 —— 与 Android 版 AppNavigation.kt 对齐
 *
 * 安卓是 HorizontalPager 三页 + 底部 Tab（闹钟 / 位置 / 设置），左右可滑动；
 * 编辑闹钟是独立全屏页（无底栏）。这里用 Swiper 实现同样的交互：
 *  - Swiper 三页：HomeView / LocationView / SettingsView
 *  - 底部 SharedTabBar：图标 22 + 文字 10sp，选中橙色加粗
 *  - 首次启动叠一层隐私政策弹窗（不可绕过）
 */
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PrivacyConsent } from '../common/PrivacyConsent';
import { ThemeManager, ThemeColors, DARK_COLORS } from '../common/AppTheme';
import { SettingsStore } from '../data/SettingsStore';
import { AlarmRepository } from '../data/AlarmRepository';
import { HomeView } from '../views/HomeView';
import { LocationView } from '../views/LocationView';
import { SettingsView } from '../views/SettingsView';

const PAGE_HOME: number = 0;
const PAGE_LOCATION: number = 1;
const PAGE_SETTINGS: number = 2;

@Entry
@Component
struct Index {
  @State privacyAgreed: boolean = false;
  @State showPrivacy: boolean = false;
  @State pageIndex: number = PAGE_HOME;
  @State colors: ThemeColors = DARK_COLORS;
  /** 各页刷新信号：切到该页时自增，子组件用 @Watch 感知 */
  @State homeTick: number = 0;
  @State locTick: number = 0;
  @State setTick: number = 0;

  private swiper: SwiperController = new SwiperController();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    this.context = getContext(this) as common.UIAbilityContext;
    try {
      await SettingsStore.init(this.context);
      await AlarmRepository.init(this.context);
      await ThemeManager.init(this.context);
      await PrivacyConsent.init(this.context);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Index] 初始化失败: ${e.code} ${e.message}`);
    }
    this.colors = ThemeManager.colors(this.context);
    this.privacyAgreed = PrivacyConsent.isAgreed();
    if (!this.privacyAgreed) {
      this.showPrivacy = true;
    }
  }

  /**
   * 从编辑页 router.back() 回来时刷新首页
   *
   * AlarmEditPage 保存后是直接 back()，Index 不会收到任何事件，
   * 若不在这里自增 homeTick，列表就还是进入编辑页之前那份数据 ——
   * 表现为「刚添加的闹钟没出现在列表里」，但数据库其实已经写入了。
   */
  onPageShow(): void {
    this.homeTick = this.homeTick + 1;
  }

  /** 切换页面：Swiper 滚动 + 刷新目标页 */
  private gotoPage(index: number): void {
    if (index === this.pageIndex) {
      return;
    }
    this.swiper.changeIndex(index);
    this.pageIndex = index;
    this.bumpTick(index);
  }

  private bumpTick(index: number): void {
    if (index === PAGE_HOME) {
      this.homeTick = this.homeTick + 1;
    } else if (index === PAGE_LOCATION) {
      this.locTick = this.locTick + 1;
    } else {
      this.setTick = this.setTick + 1;
    }
  }

  /** 点击「同意并继续」 */
  private async onPrivacyAgree(): Promise<void> {
    try {
      await PrivacyConsent.agree();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[Index] 保存隐私同意状态失败: ${e.code} ${e.message}`);
    }
    this.privacyAgreed = true;
    this.showPrivacy = false;
  }

  /** 点击「不同意并退出」 */
  private onPrivacyReject(): void {
    this.context.terminateSelf().catch((err: BusinessError) => {
      console.error(`[Index] 退出应用失败: ${err.code} ${err.message}`);
    });
  }

  build() {
    Stack() {
      Column() {
        Swiper(this.swiper) {
          HomeView({
            consented: this.privacyAgreed,
            tick: this.homeTick,
            onAddAlarm: () => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/AlarmEditPage' });
            },
            onEditAlarm: (id: number) => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/AlarmEditPage',
                params: { id: id }
              });
            },
            onLocationClick: () => { this.gotoPage(PAGE_LOCATION); }
          })

          LocationView({ tick: this.locTick })

          SettingsView({ tick: this.setTick })
        }
        .index(PAGE_HOME)
        .indicator(false)
        .loop(false)
        .duration(260)
        .layoutWeight(1)
        .onChange((index: number) => {
          this.pageIndex = index;
          this.bumpTick(index);
        })

        this.TabBar()
      }
      .width('100%')
      .height('100%')

      // ---------- 隐私政策弹窗 ----------
      if (this.showPrivacy) {
        this.privacyOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bg)
  }

  /** 底部 Tab 栏，对齐安卓 SharedBottomTabBar */
  @Builder
  TabBar() {
    Row() {
      this.TabItem('闹钟', $r('app.media.ic_alarm'), PAGE_HOME)
      this.TabItem('位置', $r('app.media.ic_location'), PAGE_LOCATION)
      this.TabItem('设置', $r('app.media.ic_settings'), PAGE_SETTINGS)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .justifyContent(FlexAlign.SpaceEvenly)
    .backgroundColor(this.colors.bg)
  }

  @Builder
  TabItem(label: string, icon: Resource, page: number) {
    Column({ space: 4 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.pageIndex === page ? this.colors.accent : this.colors.textGray)
      Text(label)
        .fontSize(10)
        .fontWeight(this.pageIndex === page ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.pageIndex === page ? this.colors.accent : this.colors.textGray)
    }
    .padding({ left: 20, right: 20, top: 2, bottom: 2 })
    .onClick(() => { this.gotoPage(page); })
  }

  /**
   * 首次启动的隐私政策提示层
   *
   * 审核要求（C2）：首次启动必须以显著方式提示用户阅读隐私政策，
   * 因此用全屏遮罩 + 独立弹窗，且不提供「点蒙层关闭」的路径——
   * 用户只能选「不同意并退出」或「同意并继续」。
   */
  @Builder
  privacyOverlay() {
    Column() {
      Column() {
        Text('用户协议与隐私政策')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.text)
        Text('请在使用「日出闹钟」前阅读并同意以下内容')
          .fontSize(12)
          .fontColor(this.colors.textGray)
          .margin({ top: 6 })

        Scroll() {
          Column({ space: 10 }) {
            Text('一、我们收集哪些信息')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.text)
              .width('100%')
            Text('· 位置信息（粗略 / 精确）：仅在你点击「定位」并授权后获取，用于在本机离线计算当地日出、日落时间。\n· 闹钟设置：你创建的时间、铃声、重复规则。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.colors.textSub)
              .width('100%')

            Text('二、信息如何存储')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.text)
              .width('100%')
              .margin({ top: 2 })
            Text('以上信息全部保存在你的设备本地，不上传服务器。本应用没有账号体系，我们无法远程读取你的数据；卸载应用即全部删除。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.colors.textSub)
              .width('100%')

            Text('三、权限用途')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.text)
              .width('100%')
              .margin({ top: 2 })
            Text('· 位置权限：计算日出日落时间，拒绝后可使用手动选择的城市。\n· 通知权限：闹钟到点时响铃提醒。\n· 网络权限：可选，仅用于在线校准日出日落数据。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.colors.textSub)
              .width('100%')

            Text('四、第三方共享')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.text)
              .width('100%')
              .margin({ top: 2 })
            Text('本应用不接入广告、统计、推送类 SDK，不会向任何第三方共享或转让你的信息。')
              .fontSize(12)
              .lineHeight(19)
              .fontColor(this.colors.textSub)
              .width('100%')

            Text('点击「同意并继续」即表示你已阅读并同意上述内容。')
              .fontSize(12)
              .fontColor(this.colors.textGray)
              .width('100%')
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height(276)
        .scrollBar(BarState.Off)
        .margin({ top: 14 })

        Row({ space: 12 }) {
          Text('不同意并退出')
            .fontSize(15)
            .fontColor(this.colors.textGray)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(23)
            .backgroundColor(this.colors.cardHover)
            .onClick(() => { this.onPrivacyReject(); })

          Text('同意并继续')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.onAccent)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(23)
            .backgroundColor(this.colors.accent)
            .onClick(() => { this.onPrivacyAgree(); })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width('88%')
      .padding({ left: 20, right: 20, top: 22, bottom: 20 })
      .backgroundColor(this.colors.card)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F20A0A0C')
    .justifyContent(FlexAlign.Center)
  }
}
