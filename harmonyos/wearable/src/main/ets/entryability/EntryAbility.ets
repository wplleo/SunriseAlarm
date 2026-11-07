import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmStore } from '../data/AlarmStore';
import { SettingsStore } from '../data/SettingsStore';
import { PrivacyConsent } from '../common/PrivacyConsent';
import { ReminderService } from '../service/ReminderService';
import { WatchTheme } from '../common/WatchTheme';

const DOMAIN: number = 0x0000;
const TAG: string = 'SunriseWatch';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    // 手表默认深色：OLED 黑底不发光，是唯一能省电的显示方案
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);

    const ctx = this.context;

    // 隐私状态要最先就绪，否则定位权限申请会被合规闸门挡住
    PrivacyConsent.init(ctx).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'PrivacyConsent 初始化完成');
      return SettingsStore.init(ctx);
    }).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'SettingsStore 初始化完成');
      return AlarmStore.init(ctx);
    }).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'AlarmStore 初始化完成');
      // 每次启动按当前数据重排一遍提醒：
      // 跨进程重启后内存里的 reminderId 全丢了，旧提醒只能靠 cancelAllReminders 清掉，
      // 不重排就会出现「改了时间但不生效」或者「提醒越积越多」
      return ReminderService.rescheduleAll(
        AlarmStore.getAll(),
        SettingsStore.getLatitude(),
        SettingsStore.getLongitude(),
        ctx
      );
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, '启动初始化失败: %{public}s', JSON.stringify(err));
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      // 圆屏手表没有状态栏区域，内容直接铺满，背景由页面自己保证是纯黑
      const win: window.Window = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen 失败: %{public}s', JSON.stringify(e));
      });
      win.setWindowBackgroundColor(WatchTheme.bg);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
