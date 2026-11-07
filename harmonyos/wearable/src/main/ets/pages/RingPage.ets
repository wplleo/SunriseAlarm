/**
 * 响铃页 —— 手表端
 *
 * 手表闹钟的核心体验是**手腕震动**，不是屏幕。所以这页的设计原则：
 *  - 界面极简：一眼看清"是什么闹钟"，两个大按钮能盲按
 *  - 震动循环：每 1.6 秒震一下，不用屏幕常亮也能吵醒
 *  - 亮屏保持：由 RingAbility 设置了 setWindowKeepScreenOn
 *
 * 注意：本页可能是被系统提醒卡片点进来的（此时拿不到 alarmId），
 * 也可能是 maxScreenWantAgent 直接拉起的。两种都要能正常关闭。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WatchTheme } from '../common/WatchTheme';
import { TimeFormat } from '../common/TimeFormat';
import { ReminderService } from '../service/ReminderService';

@Entry
@Component
struct RingPage {
  @StorageLink('ringAlarmId') alarmId: number = 0;
  @StorageLink('ringLabel') label: string = '闹钟';
  @StorageLink('ringSnoozeMinutes') snoozeMinutes: number = 5;

  @State nowText: string = '';
  @State muted: boolean = false;
  private vibrateTimer: number = -1;
  private clockTimer: number = -1;

  aboutToAppear(): void {
    this.tick();
    this.clockTimer = setInterval(() => { this.tick(); }, 1000);
    this.startVibrateLoop();
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
    this.stopVibrate();
  }

  private tick(): void {
    const d: Date = new Date();
    this.nowText = TimeFormat.clockWithMeridiem(d.getHours(), d.getMinutes());
  }

  private startVibrateLoop(): void {
    if (this.vibrateTimer >= 0) {
      return;
    }
    this.vibrateOnce();
    // 循环震动：靠间隔而不是长震动，更省电，也更接近真实闹钟手感
    this.vibrateTimer = setInterval(() => {
      if (this.muted) {
        return;
      }
      this.vibrateOnce();
    }, 1600);
  }

  private vibrateOnce(): void {
    try {
      vibrator.startVibration(
        { type: 'time', duration: 900 },
        { id: 0, usage: 'alarm' }
      ).catch((err: BusinessError) => {
        console.warn(`[RingPage] 震动失败: ${err.code} ${err.message}`);
      });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[RingPage] 震动异常: ${e.code}`);
    }
  }

  private stopVibrate(): void {
    if (this.vibrateTimer >= 0) {
      clearInterval(this.vibrateTimer);
      this.vibrateTimer = -1;
    }
    try {
      vibrator.stopVibration().catch((err: BusinessError) => {
        console.warn(`[RingPage] 停止震动失败: ${err.code}`);
      });
    } catch (err) {
      // 忽略：本就没有在震
    }
  }

  private close(): void {
    this.stopVibrate();
    try {
      const ctx: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      ctx.terminateSelf();
    } catch (err) {
      router.back();
    }
  }

  private async snooze(): Promise<void> {
    this.stopVibrate();
    this.muted = true;
    try {
      const ctx: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      await ReminderService.publishSnoozeOnce(this.alarmId, this.label, this.snoozeMinutes, ctx);
      promptAction.showToast({ message: `${this.snoozeMinutes} 分钟后再响` });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      promptAction.showToast({ message: `稍后提醒失败(${e.code})` });
    }
    this.close();
  }

  build() {
    Column() {
      Text(this.label)
        .fontSize(WatchTheme.fontCaption)
        .fontColor(WatchTheme.accent)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.nowText)
        .fontSize(30)
        .fontWeight(FontWeight.Medium)
        .fontColor(WatchTheme.text)
        .margin({ top: 2 })

      Row({ space: 7 }) {
        Button('稍后')
          .fontSize(WatchTheme.fontCaption)
          .fontColor(WatchTheme.text)
          .backgroundColor(WatchTheme.card)
          .height(34)
          .layoutWeight(1)
          .borderRadius(17)
          .onClick(() => { this.snooze(); })

        Button('关闭')
          .fontSize(WatchTheme.fontCaption)
          .fontColor(WatchTheme.bg)
          .backgroundColor(WatchTheme.accent)
          .height(34)
          .layoutWeight(1)
          .borderRadius(17)
          .onClick(() => { this.close(); })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(WatchTheme.bg)
  }
}
