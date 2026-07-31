/**
 * 日出日落时间计算器 (ArkTS 版)
 *
 * 基于 NOAA (National Oceanic and Atmospheric Administration) 算法
 * 完全离线计算，不需要网络请求。
 *
 * 原 Kotlin 实现 1:1 翻译，纯数学逻辑，零平台依赖。
 * 参考: https://gml.noaa.gov/grad/solcalc/calcdetails.html
 */

function toRadians(deg: number): number {
  return (deg * Math.PI) / 180.0;
}

function toDegrees(rad: number): number {
  return (rad * 180.0) / Math.PI;
}

export class SunTimes {
  sunrise: Date;
  sunset: Date;
  solarNoon: Date;
  daylightMinutes: number;

  constructor(sunrise: Date, sunset: Date, solarNoon: Date, daylightMinutes: number) {
    this.sunrise = sunrise;
    this.sunset = sunset;
    this.solarNoon = solarNoon;
    this.daylightMinutes = daylightMinutes;
  }
}

export class SunriseSunsetCalculator {
  /**
   * 计算指定日期、位置的日出日落时间
   *
   * @param year 年
   * @param month 月 (1-12)
   * @param day 日
   * @param latitude 纬度 (度)
   * @param longitude 经度 (度)
   * @param timeZone 时区偏移 (小时)，东为正
   * @returns SunTimes 或 null（极昼/极夜情况）
   */
  static calculate(year: number, month: number, day: number, latitude: number, longitude: number,
    timeZone: number): SunTimes | null {
    const latRad: number = toRadians(latitude);

    // 1. 计算儒略日
    const jd: number = SunriseSunsetCalculator.julianDay(year, month, day);

    // 2. 计算自 2000 年 1 月 1 日 12:00 UTC 以来的儒略世纪数
    const jc: number = (jd - 2451545.0) / 36525.0;

    // 3. 计算太阳几何平均经度（度）
    const geomMeanLong: number = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360.0;

    // 4. 计算太阳几何平均近点角（度）
    const geomMeanAnom: number = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);

    // 4.5 计算地球轨道偏心率
    const eccentricity: number = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);

    // 5. 计算太阳中心方程
    const sunEqCtr: number = Math.sin(toRadians(geomMeanAnom)) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
      Math.sin(toRadians(2 * geomMeanAnom)) * (0.019993 - 0.000101 * jc) +
      Math.sin(toRadians(3 * geomMeanAnom)) * 0.000289;

    // 6. 太阳真经度
    const sunTrueLong: number = geomMeanLong + sunEqCtr;

    // 7. 太阳视经度（考虑章动和光行差）
    const sunAppLong: number = sunTrueLong - 0.00569 - 0.00478 * Math.sin(toRadians(125.04 - 1934.136 * jc));

    // 8. 平均黄赤交角（度）
    const meanObliqEcliptic: number = 23.0 + (26.0 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60.0) / 60.0;

    // 9. 修正黄赤交角
    const obliqCorr: number = meanObliqEcliptic + 0.00256 * Math.cos(toRadians(125.04 - 1934.136 * jc));

    // 10. 太阳赤纬（度）
    const sunDeclination: number = toDegrees(Math.asin(Math.sin(toRadians(obliqCorr)) * Math.sin(toRadians(sunAppLong))));

    // 11. 时差（分钟）
    const y: number = Math.tan(toRadians(obliqCorr / 2.0));
    const y2: number = y * y;
    const eqOfTime: number = 4.0 * toDegrees(
      y2 * Math.sin(2 * toRadians(geomMeanLong)) -
      2.0 * eccentricity * Math.sin(toRadians(geomMeanAnom)) +
      4.0 * eccentricity * y2 * Math.sin(toRadians(geomMeanAnom)) * Math.cos(2 * toRadians(geomMeanLong)) -
      0.5 * y2 * y2 * Math.sin(4 * toRadians(geomMeanLong)) -
      1.25 * eccentricity * eccentricity * Math.sin(2 * toRadians(geomMeanAnom))
    );

    // 12. 日出/日落时角（度）
    const zenithAngle: number = 90.833;
    const cosValue: number = Math.cos(toRadians(zenithAngle)) / (Math.cos(latRad) * Math.cos(toRadians(sunDeclination))) -
      Math.tan(latRad) * Math.tan(toRadians(sunDeclination));

    // 极昼或极夜
    if (Number.isNaN(cosValue) || Math.abs(cosValue) > 1.0) {
      return null;
    }

    const hourAngle: number = toDegrees(Math.acos(cosValue));

    // 13. 日出/日落的中天时间（分钟，本地）
    const solarNoonMin: number = (720.0 - 4.0 * longitude - eqOfTime + timeZone * 60.0);
    const sunriseMin: number = solarNoonMin - hourAngle * 4.0;
    const sunsetMin: number = solarNoonMin + hourAngle * 4.0;

    // 14. 转换为 Date
    const calSunrise: Date = SunriseSunsetCalculator.minutesToDate(year, month, day, sunriseMin);
    const calSunset: Date = SunriseSunsetCalculator.minutesToDate(year, month, day, sunsetMin);
    const calNoon: Date = SunriseSunsetCalculator.minutesToDate(year, month, day, solarNoonMin);

    const daylight: number = Math.round(sunsetMin - sunriseMin);

    return new SunTimes(calSunrise, calSunset, calNoon, daylight);
  }

  /**
   * 便捷方法：计算今天的日出日落
   */
  static calculateToday(latitude: number, longitude: number): SunTimes | null {
    return SunriseSunsetCalculator.calculateForDate(new Date(), latitude, longitude);
  }

  /**
   * 便捷方法：计算指定日期的日出日落
   */
  static calculateForDate(date: Date, latitude: number, longitude: number): SunTimes | null {
    const tz: number = -date.getTimezoneOffset() / 60.0;
    return SunriseSunsetCalculator.calculate(
      date.getFullYear(),
      date.getMonth() + 1,
      date.getDate(),
      latitude,
      longitude,
      tz
    );
  }

  /**
   * 计算某闹钟基于日出日落的实际触发时间
   * @param alarmType 0=日出, 1=日落
   * @param offsetMinutes 偏移分钟（正=延后，负=提前）
   * @returns [hour, minute] 或 null
   */
  static calculateAlarmTime(alarmType: number, offsetMinutes: number, date: Date, latitude: number,
    longitude: number): [number, number] | null {
    const sunTimes: SunTimes | null = SunriseSunsetCalculator.calculateForDate(date, latitude, longitude);
    if (!sunTimes) {
      return null;
    }
    const base: Date = alarmType === 0 ? sunTimes.sunrise : sunTimes.sunset;
    const triggered: Date = new Date(base.getTime() + offsetMinutes * 60000);
    return [triggered.getHours(), triggered.getMinutes()];
  }

  // ---- 内部工具方法 ----

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

  private static minutesToDate(year: number, month: number, day: number, totalMinutes: number): Date {
    let mins: number = totalMinutes;
    while (mins < 0) {
      mins += 1440;
    }
    while (mins >= 1440) {
      mins -= 1440;
    }
    const totalMinsInt: number = Math.floor(mins);
    const hour: number = Math.floor(totalMinsInt / 60);
    const min: number = totalMinsInt % 60;
    return new Date(year, month - 1, day, hour, min, 0, 0);
  }

  /**
   * 格式化白昼时长，如 "12时34分"
   */
  static formatDaylight(minutes: number): string {
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    return `${h}时${m}分`;
  }

  /**
   * 格式化时间 HH:mm
   */
  static formatTime(date: Date): string {
    const hh: number = date.getHours();
    const mm: number = date.getMinutes();
    return `${hh.toString().padStart(2, '0')}:${mm.toString().padStart(2, '0')}`;
  }
}
