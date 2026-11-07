/**
 * 隐私政策同意状态 —— HarmonyOS 版
 *
 * 合规要求（对应审核驳回项 C2 / C3）：
 *  - 首次启动必须以显著方式提示用户阅读隐私政策，由用户主动同意
 *  - 未取得同意前，不得申请定位权限、不得联网、不得发布带用户位置信息的提醒
 *
 * 单独使用一个 preferences store 存放，避免与业务设置耦合：
 * 即便 SettingsStore 初始化异常，隐私状态也要能正常读写。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'sunrise_privacy';
const KEY_AGREED: string = 'agreed';
const KEY_AGREED_VERSION: string = 'agreedVersion';

/** 隐私政策版本号。条款有实质变化时递增，用户会被重新提示确认 */
export const PRIVACY_VERSION: string = '1.0';

export class PrivacyConsent {
  private static prefs: preferences.Preferences | null = null;
  private static initPromise: Promise<void> | null = null;
  /** 内存缓存，供同步判断；页面渲染时不用等异步 */
  private static agreed: boolean = false;

  /** 重复调用安全 */
  static init(context: common.UIAbilityContext): Promise<void> {
    if (PrivacyConsent.prefs !== null) {
      return Promise.resolve();
    }
    if (PrivacyConsent.initPromise === null) {
      PrivacyConsent.initPromise = (async (): Promise<void> => {
        const p: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME);
        PrivacyConsent.prefs = p;
        const has: boolean = p.getSync(KEY_AGREED, false) as boolean;
        const ver: string = p.getSync(KEY_AGREED_VERSION, '') as string;
        // 版本不一致视为未同意，需要重新确认
        PrivacyConsent.agreed = has && ver === PRIVACY_VERSION;
      })();
    }
    return PrivacyConsent.initPromise;
  }

  /** 是否已同意当前版本隐私政策（同步） */
  static isAgreed(): boolean {
    return PrivacyConsent.agreed;
  }

  /** 用户点击「同意并继续」 */
  static async agree(): Promise<void> {
    PrivacyConsent.agreed = true;
    const p: preferences.Preferences | null = PrivacyConsent.prefs;
    if (p === null) {
      return;
    }
    await p.put(KEY_AGREED, true);
    await p.put(KEY_AGREED_VERSION, PRIVACY_VERSION);
    await p.flush();
  }

  /** 撤回同意（保留给以后做「隐私设置」入口，当前未接线） */
  static async revoke(): Promise<void> {
    PrivacyConsent.agreed = false;
    const p: preferences.Preferences | null = PrivacyConsent.prefs;
    if (p === null) {
      return;
    }
    await p.put(KEY_AGREED, false);
    await p.flush();
  }
}
