import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AlarmRepository } from '../data/AlarmRepository';
import { SettingsStore } from '../data/SettingsStore';

const DOMAIN: number = 0x0000;
const TAG: string = 'SunriseAlarm';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    // 数据层初始化放在 onCreate，页面首帧就能直接读
    const ctx = this.context;
    AlarmRepository.init(ctx).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'AlarmRepository 初始化完成');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'AlarmRepository 初始化失败: %{public}s', JSON.stringify(err));
    });

    SettingsStore.init(ctx).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'SettingsStore 初始化完成');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'SettingsStore 初始化失败: %{public}s', JSON.stringify(err));
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
      // 沉浸式：内容延伸到状态栏
      const win: window.Window = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen 失败: %{public}s', JSON.stringify(e));
      });
      win.setWindowSystemBarProperties({
        statusBarContentColor: '#FFFFFF',
        navigationBarContentColor: '#FFFFFF'
      }).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'setWindowSystemBarProperties 失败: %{public}s', JSON.stringify(e));
      });
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
