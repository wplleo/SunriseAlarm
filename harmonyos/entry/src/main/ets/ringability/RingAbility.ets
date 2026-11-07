/**
 * 响铃 Ability —— 对齐 Android AlarmRingService 的全屏响铃
 *
 * 由 reminderAgentManager 的 maxScreenWantAgent 拉起：
 * 锁屏/息屏时直接全屏显示闹钟，亮屏时盖在最上层。
 * 页面里提供「稍后提醒」和「关闭」，与 Android 的行为一致。
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'SunriseAlarm';

export default class RingAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // reminderAgentManager 通过 want.parameters 传参，转存到 AppStorage 供页面读取
    const p: Record<string, Object> = (want.parameters ?? {}) as Record<string, Object>;
    const alarmId: number = Number(p['alarmId'] ?? 0);
    const label: string = String(p['label'] ?? '闹钟');
    const timeText: string = String(p['timeText'] ?? '');
    const vibrate: boolean = String(p['vibrate'] ?? 'true') !== 'false';
    const snoozeMinutes: number = Number(p['snoozeMinutes'] ?? 5);

    AppStorage.setOrCreate<number>('ringAlarmId', alarmId);
    AppStorage.setOrCreate<string>('ringLabel', label);
    AppStorage.setOrCreate<string>('ringTimeText', timeText);
    AppStorage.setOrCreate<boolean>('ringVibrate', vibrate);
    AppStorage.setOrCreate<number>('ringSnoozeMinutes', snoozeMinutes);
    hilog.info(DOMAIN, TAG, 'RingAbility onCreate alarm=%{public}d label=%{public}s', alarmId, label);
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
        // 响铃时保持屏幕常亮，对齐 Android 前台服务的体验
        win.setWindowKeepScreenOn(true).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'setWindowKeepScreenOn 失败');
        });
        win.setWindowSystemBarProperties({
          statusBarContentColor: '#FFFFFF',
          navigationBarContentColor: '#FFFFFF'
        }).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'setWindowSystemBarProperties 失败');
        });
      } catch (e) {
        hilog.warn(DOMAIN, TAG, '获取主窗口失败');
      }
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'RingAbility onDestroy');
  }
}
