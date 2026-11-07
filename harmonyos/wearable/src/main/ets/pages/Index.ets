/**
 * 手表端首页
 *
 * 结构：Swiper 三页，左右滑动切换
 *   0 今日 —— 当前地点的日出、日落、昼长
 *   1 闹钟 —— 已设闹钟列表 + 新建
 *   2 设置 —— 定位、时间制式、关于
 *
 * 圆屏布局约束（务必先读 WatchTheme 里的推算）：
 * 内容一律**垂直居中**，因为圆心处的水平可用宽度最大（233vp），
 * 越往上下两端越窄。任何贴顶或贴底的布局都会被圆弧切掉。
 * 列表类页面做不到居中，就用较大的上下内边距（40vp）+ 收窄左右宽度，
 * 让首尾项落在圆弧内的安全区里。
 */
import { router, LengthMetrics } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
// 圆形表盘专用组件：不是全局组件，必须显式引入（API 18 起）
import { ArcList, ArcListItem } from '@ohos.arkui.ArcList';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmEntity } from '../model/AlarmEntity';
import { AlarmStore } from '../data/AlarmStore';
import { SettingsStore } from '../data/SettingsStore';
import { TimeFormat } from '../common/TimeFormat';
import { WatchTheme } from '../common/WatchTheme';
import { SunriseSunsetCalculator, SunTimes } from '../common/SunriseSunsetCalculator';
import { AlarmTimeCalculator } from '../common/AlarmTimeCalculator';
import { ReminderService } from '../service/ReminderService';

@Entry
@Component
struct Index {
  @State cityName: string = SettingsStore.getLocationName();
  @State sunriseText: string = '--:--';
  @State sunsetText: string = '--:--';
  @State daylightText: string = '';
  @State alarms: AlarmEntity[] = [];
  @State loaded: boolean = false;
  @State currentPage: number = 0;
  @State hour24: boolean = true;
  @State polarNote: string = '';

  /**
   * 闹钟增删改的全局广播计数。
   *
   * 编辑页保存后自增，这里 @Watch 立刻重读列表 —— 不依赖页面生命周期。
   * 手机上曾出现「保存了但列表不更新，得退出 App 再进才显示」，
   * 手表上页面切换更频繁，更不能赌 onPageShow。
   */
  @StorageLink('watchAlarmVersion') @Watch('reload') alarmVersion: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  private reload(): void {
    this.cityName = SettingsStore.getLocationName();
    this.hour24 = SettingsStore.isHour24();
    this.computeSun();
    this.alarms = AlarmStore.getAll();
    this.loaded = true;
  }

  private computeSun(): void {
    const lat: number = SettingsStore.getLatitude();
    const lng: number = SettingsStore.getLongitude();
    const t: SunTimes | null = SunriseSunsetCalculator.calculateToday(lat, lng);
    if (t === null) {
      // 极昼 / 极夜：当天太阳不升或不落，算法返回 null
      this.sunriseText = '--:--';
      this.sunsetText = '--:--';
      this.daylightText = '';
      this.polarNote = '今天没有日出';
      return;
    }
    this.polarNote = '';
    this.sunriseText = TimeFormat.fromMinutes(t.sunriseMinutes);
    this.sunsetText = TimeFormat.fromMinutes(t.sunsetMinutes);
    this.daylightText = SunriseSunsetCalculator.formatDaylight(t.daylightMinutes);
  }

  /** 每个闹钟下一次响的时间，用于列表副标题 */
  private nextText(alarm: AlarmEntity): string {
    if (!alarm.enabled) {
      return '已关闭';
    }
    const t: Date | null = AlarmTimeCalculator.nextTrigger(
      alarm, new Date(), SettingsStore.getLatitude(), SettingsStore.getLongitude());
    if (t === null) {
      return '--:--';
    }
    return TimeFormat.clockWithMeridiem(t.getHours(), t.getMinutes());
  }

  /**
   * 列表副标题。
   *
   * 主标题已经占了一个信息位：日出/日落闹钟是「日出前 30 分钟」，普通闹钟是「07:00」。
   * 副标题若再把同样的内容拼一遍（旧写法是 `${offsetText} · ${nextText}`），
   * 一行里会出现「日出前 30 分钟」两次，第一屏就很劝退。所以这里分工：
   *   - 日出/日落：主标题讲规则，副标题讲「哪一天、几点真正响」——每天都不同，信息是新增的
   *   - 普通闹钟：主标题已是固定时刻，副标题只留重复规则
   */
  private subText(alarm: AlarmEntity): string {
    if (!alarm.enabled) {
      return `${alarm.repeatText()} · 已关闭`;
    }
    if (alarm.isSunBased()) {
      return `${alarm.repeatText()} · ${this.nextText(alarm)}`;
    }
    return alarm.repeatText();
  }

  private async toggle(alarm: AlarmEntity): Promise<void> {
    try {
      await AlarmStore.setEnabled(alarm.id, !alarm.enabled);
      // 开关一变必须立刻重排提醒，否则关了还在响、开了却不响
      const updated: AlarmEntity | null = AlarmStore.findById(alarm.id);
      if (updated !== null) {
        const ctx: common.UIAbilityContext =
          this.getUIContext().getHostContext() as common.UIAbilityContext;
        await ReminderService.schedule(
          updated, SettingsStore.getLatitude(), SettingsStore.getLongitude(), ctx);
      }
      this.reload();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `操作失败(${e.code})` });
    }
  }

  build() {
    Stack() {
      Swiper(this.swiperController) {
        this.TodayPage()
        this.AlarmPage()
        this.SettingsPage()
      }
      .index(this.currentPage)
      .loop(false)
      .indicator(false)
      .width('100%')
      .height('100%')
      .onChange((index: number) => {
        this.currentPage = index;
        if (index === 0 || index === 1) {
          this.reload();
        }
      })

      // 页码圆点：贴在底部窄区，尺寸必须很小
      Row({ space: 4 }) {
        ForEach(this.dots(), (item: number, i: number) => {
          Circle({ width: 4, height: 4 })
            .fill(i === this.currentPage ? WatchTheme.accent : WatchTheme.divider)
        }, (item: number, i: number) => `dot${i}`)
      }
      .margin({ bottom: 9 })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .backgroundColor(WatchTheme.bg)
  }

  private swiperController: SwiperController = new SwiperController();

  private dots(): number[] {
    return [0, 1, 2];
  }

  // ---------- 第 0 页：今日 ----------
  @Builder
  TodayPage() {
    Column() {
      Text(this.cityName)
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.textGray)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column() {
        Text('日出')
          .fontSize(WatchTheme.fontCaption)
          .fontColor(WatchTheme.accent)
        Text(this.sunriseText)
          .fontSize(WatchTheme.fontHero)
          .fontWeight(FontWeight.Medium)
          .fontColor(WatchTheme.text)
          .margin({ top: 1 })
      }
      .margin({ top: 6 })

      Divider()
        .width(46)
        .color(WatchTheme.divider)
        .margin({ top: 7, bottom: 7 })

      Row({ space: 5 }) {
        Text('日落')
          .fontSize(WatchTheme.fontCaption)
          .fontColor(WatchTheme.sunset)
        Text(this.sunsetText)
          .fontSize(WatchTheme.fontBody)
          .fontColor(WatchTheme.text)
      }

      Text(this.polarNote.length > 0 ? this.polarNote : `白天 ${this.daylightText}`)
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.textGray)
        .margin({ top: 5 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: WatchTheme.padH, right: WatchTheme.padH })
    .justifyContent(FlexAlign.Center)
  }

  // ---------- 第 1 页：闹钟 ----------
  @Builder
  AlarmPage() {
    Column() {
      if (!this.loaded) {
        // 首次读库未完成先留空：否则会闪一帧"暂无闹钟"
        Column().height(20)
      } else if (this.alarms.length === 0) {
        Column() {
          Text('还没有闹钟')
            .fontSize(WatchTheme.fontBody)
            .fontColor(WatchTheme.textGray)
          Text('点下面的 + 添加')
            .fontSize(WatchTheme.fontCaption)
            .fontColor(WatchTheme.divider)
            .margin({ top: 3 })
        }
        .justifyContent(FlexAlign.Center)
      } else {
        // 弧形列表：项沿圆弧排布、随距离自动缩放，圆屏上比 List 更自然
        ArcList() {
          ForEach(this.alarms, (alarm: AlarmEntity) => {
            ArcListItem() {
              Column() {
                Row() {
                  Text(alarm.isRegular() ? alarm.timeText() : alarm.offsetText())
                    .fontSize(WatchTheme.fontBody)
                    .fontColor(alarm.enabled ? WatchTheme.text : WatchTheme.textGray)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: alarm.enabled })
                    .onChange(() => { this.toggle(alarm); })
                    .width(38)
                    .height(22)
                }
                .width('100%')

                Text(this.subText(alarm))
                  .fontSize(WatchTheme.fontCaption)
                  .fontColor(WatchTheme.textGray)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 1 })
              }
              .width('100%')
              .padding({ left: 9, right: 5, top: 5, bottom: 5 })
              .backgroundColor(WatchTheme.card)
              .borderRadius(13)
              .onClick(() => {
                router.pushUrl({ url: 'pages/AlarmEditPage', params: { alarmId: alarm.id } });
              })
            }
            .autoScale(true)
          }, (alarm: AlarmEntity) => `a${alarm.id}${alarm.enabled}`)
        }
        .width('100%')
        .layoutWeight(1)
        .space(LengthMetrics.vp(5))
        .scrollBar(BarState.Off)
        .fadingEdge(true)
      }

      // 新建按钮：圆屏底部可用宽度只有 156（y=203 处），
      // 所以按钮收窄到 140 居中，而不是占满整行 —— 占满会被圆弧切掉两个角
      Button('+ 新建闹钟')
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.bg)
        .backgroundColor(WatchTheme.accent)
        .height(26)
        .width(140)
        .borderRadius(13)
        .margin({ top: 6 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AlarmEditPage', params: { alarmId: 0 } });
        })
    }
    .width('100%')
    .height('100%')
    // 顶部 44vp：内容宽 169 时，y=44 处的可用宽度才到 182
    .padding({ left: 32, right: 32, top: 44, bottom: 30 })
  }

  // ---------- 第 2 页：设置 ----------
  @Builder
  SettingsPage() {
    Column() {
      Text('设置')
        .fontSize(WatchTheme.fontTitle)
        .fontColor(WatchTheme.text)

      Column({ space: 6 }) {
        Row() {
          Text('位置')
            .fontSize(WatchTheme.fontBody)
            .fontColor(WatchTheme.text)
            .layoutWeight(1)
          Text(this.cityName)
            .fontSize(WatchTheme.fontCaption)
            .fontColor(WatchTheme.textGray)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 70 })
        }
        .width('100%')
        .padding({ left: 9, right: 9, top: 7, bottom: 7 })
        .backgroundColor(WatchTheme.card)
        .borderRadius(13)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LocationPage' });
        })

        Row() {
          Text('24 小时制')
            .fontSize(WatchTheme.fontBody)
            .fontColor(WatchTheme.text)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.hour24 })
            .onChange((isOn: boolean) => {
              SettingsStore.setHour24(isOn).then(() => {
                this.hour24 = isOn;
                this.reload();
              });
            })
            .width(38)
            .height(22)
        }
        .width('100%')
        .padding({ left: 9, right: 5, top: 5, bottom: 5 })
        .backgroundColor(WatchTheme.card)
        .borderRadius(13)
      }
      .width('100%')
      .margin({ top: 8 })

      Blank()

      Text('跟随日出醒来')
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.divider)
    }
    .width('100%')
    .height('100%')
    // 顶部 44vp：『设置』标题与两行宽卡片（169vp）都要落在圆弧内
    .padding({ left: 30, right: 30, top: 44, bottom: 26 })
  }
}
