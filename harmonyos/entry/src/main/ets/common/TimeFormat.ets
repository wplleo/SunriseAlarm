/**
 * 时间文本格式化 —— 统一入口
 *
 * 背景：设置页有「24 小时制」开关，但各页面各自拼 `HH:mm`，
 * 导致关闭开关后界面仍是 24 小时制（审核报告问题 B3）。
 * 所有要展示"几点几分"的地方都必须走这里。
 */
import { SettingsStore } from '../data/SettingsStore';
import { t } from './I18n';

export class TimeFormat {

  /** 是否 24 小时制（跟随设置） */
  static isHour24(): boolean {
    return SettingsStore.isHour24();
  }

  /** 补零到两位 */
  private static pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** 上午 / 下午；24 小时制下返回空串 */
  static meridiem(hour: number): string {
    if (TimeFormat.isHour24()) {
      return '';
    }
    return hour < 12 ? t('time.am') : t('time.pm');
  }

  /** 小时数：12 小时制下 0→12、13→1 */
  static hourValue(hour: number): number {
    if (TimeFormat.isHour24()) {
      return hour;
    }
    const h: number = hour % 12;
    return h === 0 ? 12 : h;
  }

  /**
   * 纯时间文本，不含上午/下午
   *  24 小时制 → "07:05"
   *  12 小时制 → "7:05"
   */
  static clock(hour: number, minute: number): string {
    const h: number = TimeFormat.hourValue(hour);
    const m: string = TimeFormat.pad2(minute);
    if (TimeFormat.isHour24()) {
      return `${TimeFormat.pad2(h)}:${m}`;
    }
    return `${h}:${m}`;
  }

  /**
   * 带时段的时间文本
   *  24 小时制 → "07:05"
   *  12 小时制 → "上午 7:05"
   */
  static clockWithMeridiem(hour: number, minute: number): string {
    const base: string = TimeFormat.clock(hour, minute);
    const mer: string = TimeFormat.meridiem(hour);
    return mer.length === 0 ? base : `${mer} ${base}`;
  }

  /** 从"当天第几分钟"格式化，用于日出日落时间 */
  static fromMinutes(totalMinutes: number): string {
    let mins: number = Math.floor(totalMinutes);
    while (mins < 0) {
      mins += 1440;
    }
    while (mins >= 1440) {
      mins -= 1440;
    }
    return TimeFormat.clockWithMeridiem(Math.floor(mins / 60), mins % 60);
  }
}
