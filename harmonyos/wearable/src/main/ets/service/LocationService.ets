/**
 * 定位服务 —— 手表端
 *
 * 与手机端的差异：
 *  - 手表上**没有键盘**，所以不做"输入关键词搜索城市"，
 *    改为「自动定位 + 常用城市列表点选」两条路
 *  - 保留了内置城市表，列表页直接读
 *  - 手表 GPS 功耗高、且系统限制后台定位，所以只在用户主动点「自动定位」时取一次
 */
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PrivacyConsent } from '../common/PrivacyConsent';

/** 定位结果 */
export class LocationResult {
  latitude: number;
  longitude: number;
  name: string;

  constructor(latitude: number, longitude: number, name: string) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.name = name;
  }
}

/** 内置城市 */
export class CityEntry {
  name: string;
  lat: number;
  lng: number;

  constructor(name: string, lat: number, lng: number) {
    this.name = name;
    this.lat = lat;
    this.lng = lng;
  }
}

/**
 * 常用城市表
 *
 * 手表上列表越短越好滑，所以只保留省会和一线城市 + 几个高纬度城市
 * （漠河、黑河这类冬天日出极晚的地方，正是这个 App 最需要的场景）。
 */
export const CITY_TABLE: CityEntry[] = [
  new CityEntry('北京', 39.9042, 116.4074),
  new CityEntry('上海', 31.2304, 121.4737),
  new CityEntry('广州', 23.1291, 113.2644),
  new CityEntry('深圳', 22.5431, 114.0579),
  new CityEntry('杭州', 30.2741, 120.1551),
  new CityEntry('成都', 30.5728, 104.0668),
  new CityEntry('重庆', 29.5630, 106.5516),
  new CityEntry('武汉', 30.5928, 114.3055),
  new CityEntry('西安', 34.3416, 108.9398),
  new CityEntry('南京', 32.0603, 118.7969),
  new CityEntry('天津', 39.3434, 117.3616),
  new CityEntry('苏州', 31.2989, 120.5853),
  new CityEntry('长沙', 28.2282, 112.9388),
  new CityEntry('郑州', 34.7466, 113.6254),
  new CityEntry('青岛', 36.0671, 120.3826),
  new CityEntry('沈阳', 41.8057, 123.4315),
  new CityEntry('大连', 38.9140, 121.6147),
  new CityEntry('哈尔滨', 45.8038, 126.5349),
  new CityEntry('长春', 43.8171, 125.3235),
  new CityEntry('济南', 36.6512, 117.1201),
  new CityEntry('合肥', 31.8206, 117.2272),
  new CityEntry('福州', 26.0745, 119.2965),
  new CityEntry('厦门', 24.4798, 118.0894),
  new CityEntry('南昌', 28.6820, 115.8579),
  new CityEntry('昆明', 25.0389, 102.7183),
  new CityEntry('贵阳', 26.6470, 106.6302),
  new CityEntry('南宁', 22.8170, 108.3665),
  new CityEntry('海口', 20.0444, 110.1999),
  new CityEntry('三亚', 18.2528, 109.5119),
  new CityEntry('兰州', 36.0611, 103.8343),
  new CityEntry('西宁', 36.6171, 101.7782),
  new CityEntry('银川', 38.4872, 106.2309),
  new CityEntry('乌鲁木齐', 43.8256, 87.6168),
  new CityEntry('拉萨', 29.6520, 91.1721),
  new CityEntry('呼和浩特', 40.8414, 111.7519),
  new CityEntry('太原', 37.8706, 112.5489),
  new CityEntry('石家庄', 38.0428, 114.5149),
  new CityEntry('宁波', 29.8683, 121.5440),
  new CityEntry('温州', 27.9938, 120.6994),
  new CityEntry('无锡', 31.4912, 120.3119),
  new CityEntry('佛山', 23.0218, 113.1219),
  new CityEntry('东莞', 23.0207, 113.7518),
  new CityEntry('珠海', 22.2707, 113.5767),
  new CityEntry('桂林', 25.2736, 110.2900),
  new CityEntry('洛阳', 34.6197, 112.4540),
  new CityEntry('烟台', 37.4638, 121.4479),
  new CityEntry('威海', 37.5128, 122.1201),
  new CityEntry('喀什', 39.4704, 75.9898),
  new CityEntry('漠河', 52.9704, 122.5388),
  new CityEntry('黑河', 50.2458, 127.5287),
  new CityEntry('中国香港', 22.3193, 114.1694),
  new CityEntry('中国澳门', 22.1987, 113.5439),
  new CityEntry('中国台北', 25.0330, 121.5654),
  new CityEntry('东京', 35.6762, 139.6503),
  new CityEntry('首尔', 37.5665, 126.9780),
  new CityEntry('新加坡', 1.3521, 103.8198),
  new CityEntry('曼谷', 13.7563, 100.5018),
  new CityEntry('悉尼', -33.8688, 151.2093),
  new CityEntry('伦敦', 51.5074, -0.1278),
  new CityEntry('巴黎', 48.8566, 2.3522),
  new CityEntry('纽约', 40.7128, -74.0060),
  new CityEntry('洛杉矶', 34.0522, -118.2437),
  new CityEntry('温哥华', 49.2827, -123.1207),
  new CityEntry('莫斯科', 55.7558, 37.6173),
  new CityEntry('迪拜', 25.2048, 55.2708)
];

const NEEDED_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION'
];

export class LocationService {

  /**
   * 本机是否具备定位能力。
   *
   * 虽然 SDK 的 wearable 能力表里有 Location.Core / Geocoder，
   * 但"能力集包含"不等于"这台机器有 GPS 硬件"——儿童表、部分运动表就没有。
   * 所以调用前必须用 canIUse 判断，否则在无 GPS 的表上会直接抛异常。
   */
  static isSupported(): boolean {
    return canIUse('SystemCapability.Location.Location.Core');
  }

  static isGeocoderSupported(): boolean {
    return canIUse('SystemCapability.Location.Location.Geocoder');
  }

  /** 动态申请定位权限，返回是否已授权 */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (!LocationService.isSupported()) {
      console.warn('[LocationService] 本机不支持定位能力');
      return false;
    }
    // 合规闸门：未同意隐私政策前，一律不弹权限框、不取位置
    if (!PrivacyConsent.isAgreed()) {
      console.warn('[LocationService] 未同意隐私政策，已阻止定位权限申请');
      return false;
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, NEEDED_PERMISSIONS);
      const granted: number[] = result.authResults;
      return granted.length > 0 && granted.every((code: number) => code === 0);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[LocationService] 申请权限失败: ${e.code} ${e.message}`);
      return false;
    }
  }

  /** 取一次当前位置。失败返回 null */
  static async getCurrentLocation(context: common.UIAbilityContext): Promise<LocationResult | null> {
    if (!LocationService.isSupported()) {
      return null;
    }
    const ok: boolean = await LocationService.requestPermission(context);
    if (!ok) {
      return null;
    }
    try {
      const request: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        // 手表 GPS 冷启动比手机慢，超时放宽到 15 秒
        timeoutMs: 15000,
        maxAccuracy: 0
      };
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
      const name: string = await LocationService.reverseGeocode(loc.latitude, loc.longitude);
      return new LocationResult(loc.latitude, loc.longitude, name);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[LocationService] 获取位置失败: ${e.code} ${e.message}`);
      return null;
    }
  }

  /** 逆地理编码：坐标 → 城市名。不可用时返回坐标文本 */
  static async reverseGeocode(latitude: number, longitude: number): Promise<string> {
    const fallback: string = `${latitude.toFixed(2)}°, ${longitude.toFixed(2)}°`;
    try {
      if (!LocationService.isGeocoderSupported()) {
        return fallback;
      }
      if (!geoLocationManager.isGeocoderAvailable()) {
        return fallback;
      }
      const req: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: latitude,
        longitude: longitude,
        maxItems: 1
      };
      const addresses: Array<geoLocationManager.GeoAddress> =
        await geoLocationManager.getAddressesFromLocation(req);
      if (addresses.length === 0) {
        return fallback;
      }
      const addr: geoLocationManager.GeoAddress = addresses[0];
      if (addr.locality && addr.locality.length > 0) {
        return addr.locality;
      }
      if (addr.subLocality && addr.subLocality.length > 0) {
        return addr.subLocality;
      }
      if (addr.placeName && addr.placeName.length > 0) {
        return addr.placeName;
      }
      return fallback;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[LocationService] 逆地理编码失败: ${e.code} ${e.message}`);
      return fallback;
    }
  }

  /** 按名称精确取内置城市（列表点选用） */
  static cityByName(name: string): CityEntry | null {
    for (const c of CITY_TABLE) {
      if (c.name === name) {
        return c;
      }
    }
    return null;
  }

  /** 检查是否已有定位权限（不弹窗） */
  static async hasPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = context.applicationInfo.accessTokenId;
      for (const p of NEEDED_PERMISSIONS) {
        const status: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(tokenId, p);
        if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          return false;
        }
      }
      return true;
    } catch (err) {
      return false;
    }
  }
}
