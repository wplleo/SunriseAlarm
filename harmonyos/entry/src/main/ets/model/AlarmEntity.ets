/**
 * 闹钟数据模型 —— HarmonyOS 版
 *
 * 移植自 Android 版 AlarmEntity.kt。纯逻辑，不依赖任何平台 API，
 * 数据库读写（relationalStore）在 AlarmRepository 里另行处理。
 */

import { t } from '../common/I18n';

/** 闹钟类型。数值与数据库中存储的整数一致，不要改动 */
export enum AlarmType {
  REGULAR = 0, // 普通闹钟
  SUNRISE = 1, // 日出闹钟
  SUNSET = 2   // 日落闹钟
}

/** 重复日位掩码：bit0=周一 … bit6=周日 */
export const REPEAT_EVERY_DAY: number = 0x7F;
export const REPEAT_WEEKDAYS: number = 0x1F;
export const REPEAT_ONCE: number = 0;

/** 周一 … 周日 的词典 key，下标 0 = 周一 */
const DAY_KEYS: string[] = [
  'alarm.dayMon', 'alarm.dayTue', 'alarm.dayWed', 'alarm.dayThu',
  'alarm.dayFri', 'alarm.daySat', 'alarm.daySun'
];

export class AlarmEntity {
  /** 主键，0 表示尚未入库 */
  id: number = 0;
  type: AlarmType = AlarmType.REGULAR;
  /** 普通闹钟使用：小时 */
  hour: number = 7;
  /** 普通闹钟使用：分钟 */
  minute: number = 0;
  /** 日出/日落闹钟偏移，正数延后、负数提前 */
  offsetMinutes: number = 0;
  label: string = '';
  enabled: boolean = true;
  repeatDays: number = REPEAT_EVERY_DAY;
  /** 仅用于本地音乐：存用户选的文件名。内置铃声留空，显示时按 soundUri 本地化 */
  soundName: string = '';
  soundUri: string = '';
  snoozeEnabled: boolean = true;
  snoozeMinutes: number = 5;
  vibrate: boolean = true;
  createdAt: number = Date.now();

  isSunrise(): boolean {
    return this.type === AlarmType.SUNRISE;
  }

  isSunset(): boolean {
    return this.type === AlarmType.SUNSET;
  }

  isRegular(): boolean {
    return this.type === AlarmType.REGULAR;
  }

  /** 是否日出日落类闹钟 */
  isSunBased(): boolean {
    return this.type === AlarmType.SUNRISE || this.type === AlarmType.SUNSET;
  }

  /** 判断周几是否启用，dayOfWeek: 1=周一 … 7=周日 */
  isEnabledOnDay(dayOfWeek: number): boolean {
    const bit: number = 1 << (dayOfWeek - 1);
    return (this.repeatDays & bit) !== 0;
  }

  isEveryDay(): boolean {
    return this.repeatDays === REPEAT_EVERY_DAY;
  }

  isWeekdays(): boolean {
    return this.repeatDays === REPEAT_WEEKDAYS;
  }

  /** 重复描述文本 */
  repeatText(): string {
    if (this.isEveryDay()) {
      return t('alarm.repeatEveryDay');
    }
    if (this.isWeekdays()) {
      return t('alarm.repeatWeekdays');
    }
    if (this.repeatDays === REPEAT_ONCE) {
      return t('alarm.repeatOnce');
    }
    const names: string[] = [];
    for (let i = 0; i < 7; i++) {
      if (((this.repeatDays >> i) & 1) === 1) {
        names.push(t(DAY_KEYS[i]));
      }
    }
    return names.join(t('alarm.daySeparator'));
  }

  /** 普通闹钟的时间文本，如 "07:30" */
  timeText(): string {
    const h: string = this.hour < 10 ? `0${this.hour}` : `${this.hour}`;
    const m: string = this.minute < 10 ? `0${this.minute}` : `${this.minute}`;
    return `${h}:${m}`;
  }

  /** 偏移描述，如 "日出前 30 分钟" / "日落后 10 分钟" */
  offsetText(): string {
    const base: string = this.isSunrise() ? t('alarm.sunrise') : t('alarm.sunset');
    const abs: number = Math.abs(this.offsetMinutes);
    if (abs === 0) {
      return base;
    }
    return this.offsetMinutes > 0
      ? t('alarm.offsetAfter', [base, abs])
      : t('alarm.offsetBefore', [base, abs]);
  }

  /** 深拷贝，编辑页取消时回滚用 */
  copy(): AlarmEntity {
    const e: AlarmEntity = new AlarmEntity();
    e.id = this.id;
    e.type = this.type;
    e.hour = this.hour;
    e.minute = this.minute;
    e.offsetMinutes = this.offsetMinutes;
    e.label = this.label;
    e.enabled = this.enabled;
    e.repeatDays = this.repeatDays;
    e.soundName = this.soundName;
    e.soundUri = this.soundUri;
    e.snoozeEnabled = this.snoozeEnabled;
    e.snoozeMinutes = this.snoozeMinutes;
    e.vibrate = this.vibrate;
    e.createdAt = this.createdAt;
    return e;
  }
}
