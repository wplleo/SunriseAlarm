/**
 * 响铃 Ability —— 手表端
 *
 * 由 reminderAgentManager 的 maxScreenWantAgent 拉起（若穿戴设备不支持该字段，
 * ReminderService 会自动降级为系统提醒卡片，此时本 Ability 不会被调用，属正常）。
 *
 * 注意：MaxScreenWantAgent **不能携带 parameters**，所以这里拿不到具体是哪个闹钟。
 * 手表屏幕太小，也不适合展示"哪个闹钟"，统一显示「日出闹钟」大标题即可。
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'SunriseWatch';

export default class RingAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const p: Record<string, Object> = (want.parameters ?? {}) as Record<string, Object>;
    const alarmId: number = Number(p['alarmId'] ?? 0);
    const label: string = String(p['label'] ?? '闹钟');
    const snoozeMinutes: number = Number(p['snoozeMinutes'] ?? 5);

    AppStorage.setOrCreate<number>('ringAlarmId', alarmId);
    AppStorage.setOrCreate<string>('ringLabel', label);
    AppStorage.setOrCreate<number>('ringSnoozeMinutes', snoozeMinutes);
    hilog.info(DOMAIN, TAG, 'RingAbility onCreate alarm=%{public}d', alarmId);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 连续两个闹钟同时到点时复用同一个 ability
    this.onCreate(want, launchParam);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/RingPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'RingPage loadContent 失败: %{public}s', JSON.stringify(err));
        return;
      }
      try {
        const win: window.Window = windowStage.getMainWindowSync();
        win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen 失败');
        });
        // 响铃期间保持亮屏，否则手腕垂下就黑屏，用户看不到"关闭"按钮
        win.setWindowKeepScreenOn(true).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'setWindowKeepScreenOn 失败');
        });
      } catch (e) {
        hilog.warn(DOMAIN, TAG, '获取主窗口失败');
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'RingAbility onWindowStageDestroy');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'RingAbility onDestroy');
  }
}
