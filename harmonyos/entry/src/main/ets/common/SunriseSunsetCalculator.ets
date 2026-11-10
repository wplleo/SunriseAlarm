/**
 * 日出日落时间计算器 —— HarmonyOS 版
 *
 * 基于 NOAA (National Oceanic and Atmospheric Administration) 算法，纯离线计算。
 * 移植自 Android 版 SunriseSunsetCalculator.kt，公式逐行对应，不依赖任何平台 API。
 *
 * 参考: https://gml.noaa.gov/grad/solcalc/calcdetails.html
 */
import { TimeFormat } from './TimeFormat';
import { t } from './I18n';

const DEG_TO_RAD: number = Math.PI / 180.0;
const RAD_TO_DEG: number = 180.0 / Math.PI;
const MINUTES_PER_DAY: number = 1440.0;

/** 日出日落计算结果，时间统一用「当天 0 点起的分钟数」表示，避免时区与 Calendar 差异 */
export class SunTimes {
  sunriseMinutes: number;
  sunsetMinutes: number;
  solarNoonMinutes: number;
  daylightMinutes: number;

  constructor(
    sunriseMinutes: number,
    sunsetMinutes: number,
    solarNoonMinutes: number,
    daylightMinutes: number
  ) {
    this.sunriseMinutes = sunriseMinutes;
    this.sunsetMinutes = sunsetMinutes;
    this.solarNoonMinutes = solarNoonMinutes;
    this.daylightMinutes = daylightMinutes;
  }
}

/** 时钟时间（时:分） */
export class ClockTime {
  hour: number;
  minute: number;

  constructor(hour: number, minute: number) {
    this.hour = hour;
    this.minute = minute;
  }
}

export class SunriseSunsetCalculator {

  /**
   * 计算指定日期、位置的日出日落时间
   *
   * @param year 年
   * @param month 月（1-12）
   * @param day 日
   * @param latitude 纬度（度）
   * @param longitude 经度（度）
   * @param timeZoneOffsetHours 时区偏移（小时），北京时间传 8
   * @returns 计算结果；极昼或极夜返回 null
   */
  static calculate(
    year: number,
    month: number,
    day: number,
    latitude: number,
    longitude: number,
    timeZoneOffsetHours: number
  ): SunTimes | null {
    const latRad: number = latitude * DEG_TO_RAD;

    // 1. 儒略日
    const jd: number = SunriseSunsetCalculator.julianDay(year, month, day);

    // 2. 自 J2000.0 起的儒略世纪数
    const jc: number = (jd - 2451545.0) / 36525.0;

    // 3. 太阳几何平均经度（度）
    const geomMeanLong: number =
      SunriseSunsetCalculator.mod360(280.46646 + jc * (36000.76983 + jc * 0.0003032));

    // 4. 太阳几何平均近点角（度）
    const geomMeanAnom: number = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);

    // 5. 地球轨道偏心率
    const eccentricity: number = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);

    // 6. 太阳中心方程
    const sunEqCtr: number =
      Math.sin(geomMeanAnom * DEG_TO_RAD) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
      Math.sin(2.0 * geomMeanAnom * DEG_TO_RAD) * (0.019993 - 0.000101 * jc) +
      Math.sin(3.0 * geomMeanAnom * DEG_TO_RAD) * 0.000289;

    // 7. 太阳真经度
    const sunTrueLong: number = geomMeanLong + sunEqCtr;

    // 8. 太阳视经度（含章动与光行差修正）
    const sunAppLong: number =
      sunTrueLong - 0.00569 - 0.00478 * Math.sin((125.04 - 1934.136 * jc) * DEG_TO_RAD);

    // 9. 平均黄赤交角（度）
    const meanObliqEcliptic: number =
      23.0 + (26.0 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60.0) / 60.0;

    // 10. 修正后的黄赤交角
    const obliqCorr: number =
      meanObliqEcliptic + 0.00256 * Math.cos((125.04 - 1934.136 * jc) * DEG_TO_RAD);

    // 11. 太阳赤纬（度）
    const sunDeclination: number =
      Math.asin(Math.sin(obliqCorr * DEG_TO_RAD) * Math.sin(sunAppLong * DEG_TO_RAD)) * RAD_TO_DEG;

    // 12. 时差（分钟）
    const y: number = Math.tan((obliqCorr / 2.0) * DEG_TO_RAD);
    const y2: number = y * y;
    const eqOfTime: number = 4.0 * RAD_TO_DEG * (
      y2 * Math.sin(2.0 * geomMeanLong * DEG_TO_RAD) -
      2.0 * eccentricity * Math.sin(geomMeanAnom * DEG_TO_RAD) +
      4.0 * eccentricity * y2 * Math.sin(geomMeanAnom * DEG_TO_RAD) *
        Math.cos(2.0 * geomMeanLong * DEG_TO_RAD) -
      0.5 * y2 * y2 * Math.sin(4.0 * geomMeanLong * DEG_TO_RAD) -
      1.25 * eccentricity * eccentricity * Math.sin(2.0 * geomMeanAnom * DEG_TO_RAD)
    );

    // 13. 日出日落时角（度），90.833° 已包含大气折射与太阳视半径
    const zenithAngle: number = 90.833;
    const cosHourAngle: number =
      Math.cos(zenithAngle * DEG_TO_RAD) /
        (Math.cos(latRad) * Math.cos(sunDeclination * DEG_TO_RAD)) -
      Math.tan(latRad) * Math.tan(sunDeclination * DEG_TO_RAD);

    // 超出 [-1, 1] 说明当天太阳不升或不落
    if (isNaN(cosHourAngle) || Math.abs(cosHourAngle) > 1.0) {
      return null;
    }

    const hourAngle: number = Math.acos(cosHourAngle) * RAD_TO_DEG;

    // 14. 换算为当地时间的分钟数
    const solarNoonMin: number =
      720.0 - 4.0 * longitude - eqOfTime + timeZoneOffsetHours * 60.0;
    const sunriseMin: number = solarNoonMin - hourAngle * 4.0;
    const sunsetMin: number = solarNoonMin + hourAngle * 4.0;

    return new SunTimes(
      sunriseMin,
      sunsetMin,
      solarNoonMin,
      Math.round(sunsetMin - sunriseMin)
    );
  }

  /** 计算今天的日出日落（按设备当前时区） */
  static calculateToday(latitude: number, longitude: number): SunTimes | null {
    const now: Date = new Date();
    const tzOffsetHours: number = -now.getTimezoneOffset() / 60.0;
    return SunriseSunsetCalculator.calculate(
      now.getFullYear(),
      now.getMonth() + 1,
      now.getDate(),
      latitude,
      longitude,
      tzOffsetHours
    );
  }

  /** 计算指定日期的日出日落 */
  static calculateForDate(date: Date, latitude: number, longitude: number): SunTimes | null {
    const tzOffsetHours: number = -date.getTimezoneOffset() / 60.0;
    return SunriseSunsetCalculator.calculate(
      date.getFullYear(),
      date.getMonth() + 1,
      date.getDate(),
      latitude,
      longitude,
      tzOffsetHours
    );
  }

  /**
   * 计算闹钟实际触发时间
   *
   * @param isSunrise true=日出，false=日落
   * @param offsetMinutes 偏移分钟（正数延后，负数提前）
   * @returns 时钟时间；极昼极夜返回 null
   */
  static calculateAlarmTime(
    isSunrise: boolean,
    offsetMinutes: number,
    date: Date,
    latitude: number,
    longitude: number
  ): ClockTime | null {
    const sunTimes: SunTimes | null =
      SunriseSunsetCalculator.calculateForDate(date, latitude, longitude);
    if (sunTimes === null) {
      return null;
    }
    const baseMinutes: number = isSunrise ? sunTimes.sunriseMinutes : sunTimes.sunsetMinutes;
    return SunriseSunsetCalculator.toClock(baseMinutes + offsetMinutes);
  }

  /** 分钟数转时钟时间，自动处理跨天 */
  static toClock(totalMinutes: number): ClockTime {
    let mins: number = totalMinutes;
    while (mins < 0) {
      mins += MINUTES_PER_DAY;
    }
    while (mins >= MINUTES_PER_DAY) {
      mins -= MINUTES_PER_DAY;
    }
    const total: number = Math.floor(mins);
    return new ClockTime(Math.floor(total / 60), total % 60);
  }

  /** 格式化时间，跟随「24 小时制」设置 */
  static formatTime(totalMinutes: number): string {
    const clock: ClockTime = SunriseSunsetCalculator.toClock(totalMinutes);
    return TimeFormat.clockWithMeridiem(clock.hour, clock.minute);
  }

  /** 格式化白昼时长，如 "12时34分" */
  static formatDaylight(minutes: number): string {
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    return t('common.durationHM', [h, m]);
  }

  // ---- 内部工具 ----

  private static julianDay(year: number, month: number, day: number): number {
    let y: number = year;
    let m: number = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    const a: number = Math.floor(y / 100.0);
    const b: number = 2 - a + Math.floor(a / 4.0);
    return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + day + b - 1524.5;
  }

  private static mod360(deg: number): number {
    const r: number = deg % 360.0;
    return r < 0 ? r + 360.0 : r;
  }

  private static pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }
}
