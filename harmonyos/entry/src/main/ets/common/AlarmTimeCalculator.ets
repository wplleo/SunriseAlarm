/**
 * 闹钟触发时间计算 —— HarmonyOS 版
 *
 * 纯逻辑，不依赖平台 API，可用 Node 直接验证。
 * 负责回答一个问题：这个闹钟下一次什么时候响。
 */
import { AlarmEntity, REPEAT_ONCE } from '../model/AlarmEntity';
import { SunriseSunsetCalculator, SunTimes } from '../common/SunriseSunsetCalculator';

const MINUTES_PER_DAY: number = 1440;

export class AlarmTimeCalculator {

  /**
   * 计算下一次触发时间
   *
   * @param alarm 闹钟
   * @param now 当前时间
   * @param latitude 当前纬度
   * @param longitude 当前经度
   * @returns 下一次触发时间；无法计算（如极昼极夜且只有日出闹钟）返回 null
   */
  static nextTrigger(
    alarm: AlarmEntity,
    now: Date,
    latitude: number,
    longitude: number
  ): Date | null {
    const baseDay: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // 最多往后看 8 天，足够覆盖一周循环 + 今天已过的情况
    for (let d = 0; d < 8; d++) {
      const day: Date = new Date(baseDay.getTime());
      day.setDate(day.getDate() + d);

      const dow: number = day.getDay(); // 0=周日
      const dayOfWeek: number = dow === 0 ? 7 : dow; // 转成 1=周一 … 7=周日

      // repeatDays 为 0 表示仅响一次，不受星期限制
      if (alarm.repeatDays !== REPEAT_ONCE && !alarm.isEnabledOnDay(dayOfWeek)) {
        continue;
      }

      let targetMinutes: number;
      if (alarm.isRegular()) {
        targetMinutes = alarm.hour * 60 + alarm.minute;
      } else {
        const sunTimes: SunTimes | null =
          SunriseSunsetCalculator.calculateForDate(day, latitude, longitude);
        if (sunTimes === null) {
          continue; // 极昼极夜，跳过这一天
        }
        const base: number = alarm.isSunrise() ? sunTimes.sunriseMinutes : sunTimes.sunsetMinutes;
        targetMinutes = base + alarm.offsetMinutes;
      }

      // 偏移可能把时间推出当天范围，做跨天修正
      let dayOffset: number = 0;
      while (targetMinutes < 0) {
        targetMinutes += MINUTES_PER_DAY;
        dayOffset -= 1;
      }
      while (targetMinutes >= MINUTES_PER_DAY) {
        targetMinutes -= MINUTES_PER_DAY;
        dayOffset += 1;
      }

      const trigger: Date = new Date(day.getTime());
      trigger.setDate(trigger.getDate() + dayOffset);
      trigger.setHours(Math.floor(targetMinutes / 60), Math.floor(targetMinutes % 60), 0, 0);

      if (trigger.getTime() > now.getTime()) {
        return trigger;
      }
    }

    return null;
  }

  /**
   * 计算闹钟"将要响的时间"用于界面展示
   * 与 nextTrigger 相同，但把结果格式化为 HH:mm
   */
  static nextTriggerText(
    alarm: AlarmEntity,
    now: Date,
    latitude: number,
    longitude: number
  ): string {
    const t: Date | null = AlarmTimeCalculator.nextTrigger(alarm, now, latitude, longitude);
    if (t === null) {
      return '--:--';
    }
    const h: number = t.getHours();
    const m: number = t.getMinutes();
    return `${h < 10 ? '0' + h : h}:${m < 10 ? '0' + m : m}`;
  }
}
