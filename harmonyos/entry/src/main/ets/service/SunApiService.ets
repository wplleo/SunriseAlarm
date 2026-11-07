/**
 * 在线日出日落校准服务 —— HarmonyOS 版
 *
 * 用 sunrise-sunset.org 的公开 API 对离线 NOAA 结果做校准。
 * 网络不可用时返回 null，由调用方回退到离线计算。
 *
 * 注意：本文件依赖 @kit.NetworkKit，需在 DevEco Studio 环境中编译验证。
 */
import { http } from '@kit.NetworkKit';
import { PrivacyConsent } from '../common/PrivacyConsent';

/** API 返回结构 */
interface ApiResults {
  sunrise: string;
  sunset: string;
  day_length: number;
}

interface ApiResponse {
  results: ApiResults;
  status: string;
}

/** 校准结果：当天 0 点起的分钟数 */
export class ApiSunTimes {
  sunriseMinutes: number;
  sunsetMinutes: number;

  constructor(sunriseMinutes: number, sunsetMinutes: number) {
    this.sunriseMinutes = sunriseMinutes;
    this.sunsetMinutes = sunsetMinutes;
  }
}

const ENDPOINT: string = 'https://api.sunrise-sunset.org/json';
const TIMEOUT_MS: number = 8000;

export class SunApiService {

  /**
   * 拉取指定日期与位置的在线日出日落
   * @returns 结果；网络失败或数据异常返回 null
   */
  static async fetchSunTimes(
    latitude: number,
    longitude: number,
    date: Date
  ): Promise<ApiSunTimes | null> {
    // 合规闸门：未同意隐私政策前不联网，直接用本地离线结果
    if (!PrivacyConsent.isAgreed()) {
      return null;
    }
    const url: string = SunApiService.buildUrl(latitude, longitude, date);
    const req: http.HttpRequest = http.createHttp();

    try {
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: TIMEOUT_MS,
        readTimeout: TIMEOUT_MS,
        header: { 'Accept': 'application/json' }
      });

      if (resp.responseCode !== 200) {
        return null;
      }

      const body: string = typeof resp.result === 'string'
        ? resp.result as string
        : JSON.stringify(resp.result);

      return SunApiService.parse(body, date);
    } catch (e) {
      // 静默失败，交由上层回退离线算法
      return null;
    } finally {
      req.destroy();
    }
  }

  /** 组装请求地址 */
  static buildUrl(latitude: number, longitude: number, date: Date): string {
    const y: number = date.getFullYear();
    const m: number = date.getMonth() + 1;
    const d: number = date.getDate();
    const mm: string = m < 10 ? `0${m}` : `${m}`;
    const dd: string = d < 10 ? `0${d}` : `${d}`;
    return `${ENDPOINT}?lat=${latitude}&lng=${longitude}&date=${y}-${mm}-${dd}&formatted=0`;
  }

  /** 解析响应体 */
  static parse(body: string, date: Date): ApiSunTimes | null {
    let json: ApiResponse;
    try {
      json = JSON.parse(body) as ApiResponse;
    } catch (e) {
      return null;
    }

    if (json === null || json.status !== 'OK' || json.results === undefined) {
      return null;
    }

    const sunriseMin: number = SunApiService.isoToLocalMinutes(json.results.sunrise, date);
    const sunsetMin: number = SunApiService.isoToLocalMinutes(json.results.sunset, date);

    if (sunriseMin < 0 || sunsetMin < 0) {
      return null;
    }
    return new ApiSunTimes(sunriseMin, sunsetMin);
  }

  /**
   * ISO8601 时间字符串转当天本地分钟数
   * 例：2026-10-26T22:36:12+00:00 → 东八区得到 06:36 → 396
   */
  static isoToLocalMinutes(iso: string, date: Date): number {
    const ts: number = Date.parse(iso);
    if (isNaN(ts)) {
      return -1;
    }
    const local: Date = new Date(ts);
    // 只有与目标日期同一天才有效，否则说明跨天，交给离线算法处理
    if (local.getFullYear() !== date.getFullYear()
      || local.getMonth() !== date.getMonth()
      || local.getDate() !== date.getDate()) {
      return -1;
    }
    return local.getHours() * 60 + local.getMinutes();
  }
}
