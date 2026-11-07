/**
 * 全屏响铃页 —— 对齐 Android AlarmRingService 的全屏通知体验
 *
 * 只负责展示与操作，铃声由系统的提醒通道播放（避免与系统提醒重复出声）。
 * 振动由本页控制，尊重闹钟的 vibrate 开关。
 */
import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeManager, ThemeColors, DARK_COLORS } from '../common/AppTheme';
import { ReminderService } from '../service/ReminderService';
import { TimeFormat } from '../common/TimeFormat';

@Entry
@Component
struct RingPage {
  @State colors: ThemeColors = DARK_COLORS;
  @State alarmId: number = 0;
  @State label: string = '闹钟';
  @State timeText: string = '';
  @State snoozeMinutes: number = 5;
  @State nowText: string = '';
  @State busy: boolean = false;

  private timer: number = -1;
  private vibrateTimer: number = -1;

  async aboutToAppear(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await ThemeManager.init(ctx);
    } catch (e) {
      console.warn('[Ring] 主题初始化失败');
    }
    this.colors = ThemeManager.colors(ctx);

    this.alarmId = AppStorage.get<number>('ringAlarmId') ?? 0;
    this.label = AppStorage.get<string>('ringLabel') ?? '闹钟';
    this.timeText = AppStorage.get<string>('ringTimeText') ?? '';
    this.snoozeMinutes = AppStorage.get<number>('ringSnoozeMinutes') ?? 5;
    const shouldVibrate: boolean = AppStorage.get<boolean>('ringVibrate') ?? true;

    this.updateClock();
    this.timer = setInterval(() => { this.updateClock(); }, 1000);
    if (shouldVibrate) {
      this.startVibrateLoop();
    }
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.stopVibrate();
  }

  updateClock(): void {
    const d: Date = new Date();
    this.nowText = TimeFormat.clock(d.getHours(), d.getMinutes());
  }

  startVibrateLoop(): void {
    this.pulse();
    this.vibrateTimer = setInterval(() => { this.pulse(); }, 1600);
  }

  pulse(): void {
    try {
      vibrator.startVibration(
        { type: 'time', duration: 800 },
        { id: 0, usage: 'alarm' }
      ).catch((e: BusinessError) => {
        console.warn(`[Ring] 振动失败: ${e.code}`);
      });
    } catch (e) {
      console.warn('[Ring] 振动不可用');
    }
  }

  stopVibrate(): void {
    if (this.vibrateTimer >= 0) {
      clearInterval(this.vibrateTimer);
      this.vibrateTimer = -1;
    }
    try {
      vibrator.stopVibration();
    } catch (e) {
      // 忽略
    }
  }

  /** 稍后提醒：排一个 N 分钟后的一次性提醒，然后退出 */
  async onSnooze(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await ReminderService.publishSnoozeOnce(this.alarmId, this.label, this.snoozeMinutes, ctx);
    } catch (e) {
      console.warn('[Ring] 稍后提醒设置失败');
    }
    this.stopVibrate();
    this.finish();
  }

  onDismiss(): void {
    this.stopVibrate();
    this.finish();
  }

  finish(): void {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    ctx.terminateSelf().catch((e: BusinessError) => {
      console.warn(`[Ring] 退出失败: ${e.code}`);
    });
  }

  build() {
    Column() {
      Blank()

      Column({ space: 10 }) {
        Text(this.label)
          .fontSize(20)
          .fontColor(this.colors.textSub)
          .fontWeight(FontWeight.Medium)

        Text(this.nowText.length > 0 ? this.nowText : (this.timeText.length > 0 ? this.timeText : '--:--'))
          .fontSize(84)
          .fontColor(this.colors.text)
          .fontWeight(FontWeight.Lighter)

        Text('闹钟响铃中')
          .fontSize(15)
          .fontColor(this.colors.textGray)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()

      Column({ space: 14 }) {
        Text(`稍后提醒（${this.snoozeMinutes} 分钟）`)
          .fontSize(17)
          .fontColor(this.colors.onAccent)
          .width('100%')
          .height(56)
          .textAlign(TextAlign.Center)
          .borderRadius(28)
          .backgroundColor(this.colors.accent)
          .onClick(() => { this.onSnooze(); })

        Text('关闭闹钟')
          .fontSize(17)
          .fontColor(this.colors.text)
          .width('100%')
          .height(56)
          .textAlign(TextAlign.Center)
          .borderRadius(28)
          .backgroundColor(this.colors.cardHover)
          .onClick(() => { this.onDismiss(); })
      }
      .width('100%')
      .padding({ left: 28, right: 28 })
      .margin({ bottom: 56 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.bg)
    .padding({ top: 60 })
  }
}
