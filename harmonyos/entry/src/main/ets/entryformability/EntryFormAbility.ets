/**
 * 服务卡片（2*2）—— 桌面显示当地今日日出 / 日落
 *
 * 注意：这里**不能**复用 SettingsStore，因为它的 init() 要求 UIAbilityContext，
 * 而卡片跑在 FormExtensionAbility 里只有 ExtensionContext。
 * 所以直接读同一个 preferences 文件（sunrise_settings），键名与 SettingsStore 对齐。
 * 日出日落是纯函数计算（SunriseSunsetCalculator），不依赖任何 Context。
 */
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { common, Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SunriseSunsetCalculator, SunTimes } from '../common/SunriseSunsetCalculator';
import { DEFAULT_LATITUDE, DEFAULT_LONGITUDE, DEFAULT_LOCATION_NAME } from '../data/SettingsStore';
import { t } from '../common/I18n';

const DOMAIN: number = 0x0000;
const TAG: string = 'SunriseAlarm';

/** 与 SettingsStore 保持一致的存储名与键名 */
const STORE_NAME: string = 'sunrise_settings';
const KEY_LATITUDE: string = 'latitude';
const KEY_LONGITUDE: string = 'longitude';
const KEY_LOCATION_NAME: string = 'locationName';
const KEY_HOUR24: string = 'hour24';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 分钟数 → 展示文本，跟随 24 小时制开关 */
function formatMinutes(totalMinutes: number, hour24: boolean): string {
  const h: number = Math.floor(totalMinutes / 60) % 24;
  const m: number = totalMinutes % 60;
  if (hour24) {
    return `${pad2(h)}:${pad2(m)}`;
  }
  const h12: number = h % 12 === 0 ? 12 : h % 12;
  return `${h < 12 ? t('common.am') : t('common.pm')}${h12}:${pad2(m)}`;
}

function durationText(minutes: number): string {
  const h: number = Math.floor(minutes / 60);
  const m: number = minutes % 60;
  return m === 0 ? t('widget.durationHour', [h]) : t('widget.durationHourMin', [h, m]);
}

/** 卡片绑定数据：卡片里用 @LocalStorageProp 同名取用 */
function buildFormData(context: common.Context): Record<string, string> {
  let latitude: number = DEFAULT_LATITUDE;
  let longitude: number = DEFAULT_LONGITUDE;
  let locationName: string = DEFAULT_LOCATION_NAME;
  let hour24: boolean = true;

  try {
    const prefs: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
    latitude = prefs.getSync(KEY_LATITUDE, DEFAULT_LATITUDE) as number;
    longitude = prefs.getSync(KEY_LONGITUDE, DEFAULT_LONGITUDE) as number;
    locationName = prefs.getSync(KEY_LOCATION_NAME, DEFAULT_LOCATION_NAME) as string;
    hour24 = prefs.getSync(KEY_HOUR24, true) as boolean;
  } catch (err) {
    const e: BusinessError = err as BusinessError;
    hilog.warn(DOMAIN, TAG, '卡片读取偏好失败: %{public}d %{public}s', e.code, e.message);
  }

  const sun: SunTimes | null = SunriseSunsetCalculator.calculateToday(latitude, longitude);
  if (sun === null) {
    // 极昼/极夜等算不出日出日落的情况
    return {
      'city': locationName,
      'sunrise': '--:--',
      'sunset': '--:--',
      'daylight': t('widget.polar'),
      'daylightLabel': ''
    };
  }

  return {
    'city': locationName,
    'sunrise': formatMinutes(sun.sunriseMinutes, hour24),
    'sunset': formatMinutes(sun.sunsetMinutes, hour24),
    'daylight': durationText(sun.daylightMinutes),
    'daylightLabel': t('widget.daylight')
  };
}

export default class EntryFormAbility extends FormExtensionAbility {

  /** 添加卡片：先回一份占位，再异步补真实数据（onAddForm 只能同步返回） */
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = AppStorageHolder.readFormId(want);
    if (formId.length > 0) {
      this.refresh(formId);
    }
    return formBindingData.createFormBindingData({
      'city': DEFAULT_LOCATION_NAME,
      'sunrise': '--:--',
      'sunset': '--:--',
      'daylight': '',
      'daylightLabel': ''
    });
  }

  /** 系统定时刷新（form_config 的 updateDuration） */
  onUpdateForm(formId: string): void {
    this.refresh(formId);
  }

  onCastToNormalForm(formId: string): void {
    this.refresh(formId);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, '卡片已移除 %{public}s', formId);
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, '卡片事件 %{public}s: %{public}s', formId, message);
    this.refresh(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  /** 算好数据后推给卡片 */
  private refresh(formId: string): void {
    try {
      const data: Record<string, string> = buildFormData(this.context);
      formProvider.updateForm(formId, formBindingData.createFormBindingData(data))
        .catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, '卡片更新失败 %{public}d %{public}s', err.code, err.message);
        });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, '卡片刷新异常 %{public}d %{public}s', e.code, e.message);
    }
  }
}

/** 从 want 里取 formId */
class AppStorageHolder {
  static readFormId(want: Want): string {
    const params: Record<string, Object> | undefined = want.parameters;
    if (params === undefined) {
      return '';
    }
    const id: Object | undefined = params[formInfo.FormParam.IDENTITY_KEY];
    return id === undefined ? '' : String(id);
  }
}
