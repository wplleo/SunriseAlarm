/**
 * 定位服务 —— HarmonyOS 版
 *
 * 替代 Android 版的 FusedLocationProviderClient。
 * 只用系统 geoLocationManager：先申请权限，再取一次当前位置，最后逆地理编码出城市名。
 */
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PrivacyConsent } from '../common/PrivacyConsent';
import { Locale } from '../common/I18n';
import { SettingsStore, SavedLocation } from '../data/SettingsStore';

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

/**
 * 定位权限：精确（LOCATION）与模糊（APPROXIMATELY_LOCATION）**同属一个权限组**，
 * 不能放在一次 requestPermissionsFromUser 里申请 —— 一起申请时系统返回的
 * authResults 是非 0，于是「用户明明已经开了权限，应用却提示定位失败」
 * （AGC 审核问题 1-5）。所以拆成两个常量，分开申请、分开判定。
 */
const PRECISE_PERMISSION: Permissions = 'ohos.permission.LOCATION';
const FUZZY_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';

/** 内置城市（含常用别名，用于离线模糊搜索） */
class CityEntry {
  name: string = '';
  lat: number = 0;
  lng: number = 0;
  /** 拼音/别名，命中即可 */
  keys: string = '';

  constructor(name: string, lat: number, lng: number, keys: string) {
    this.name = name;
    this.lat = lat;
    this.lng = lng;
    this.keys = keys;
  }
}

const CITY_TABLE: CityEntry[] = [
  new CityEntry('北京', 39.9042, 116.4074, 'beijing bj 首都'),
  new CityEntry('上海', 31.2304, 121.4737, 'shanghai sh'),
  new CityEntry('广州', 23.1291, 113.2644, 'guangzhou gz'),
  new CityEntry('深圳', 22.5431, 114.0579, 'shenzhen sz'),
  new CityEntry('杭州', 30.2741, 120.1551, 'hangzhou hz'),
  new CityEntry('成都', 30.5728, 104.0668, 'chengdu cd'),
  new CityEntry('重庆', 29.5630, 106.5516, 'chongqing cq'),
  new CityEntry('武汉', 30.5928, 114.3055, 'wuhan wh'),
  new CityEntry('西安', 34.3416, 108.9398, 'xian xa'),
  new CityEntry('南京', 32.0603, 118.7969, 'nanjing nj'),
  new CityEntry('天津', 39.3434, 117.3616, 'tianjin tj'),
  new CityEntry('苏州', 31.2989, 120.5853, 'suzhou sz'),
  new CityEntry('长沙', 28.2282, 112.9388, 'changsha cs'),
  new CityEntry('郑州', 34.7466, 113.6254, 'zhengzhou zz'),
  new CityEntry('青岛', 36.0671, 120.3826, 'qingdao qd'),
  new CityEntry('沈阳', 41.8057, 123.4315, 'shenyang sy'),
  new CityEntry('大连', 38.9140, 121.6147, 'dalian dl'),
  new CityEntry('哈尔滨', 45.8038, 126.5349, 'haerbin heb 冰城'),
  new CityEntry('长春', 43.8171, 125.3235, 'changchun cc'),
  new CityEntry('济南', 36.6512, 117.1201, 'jinan jn'),
  new CityEntry('合肥', 31.8206, 117.2272, 'hefei hf'),
  new CityEntry('福州', 26.0745, 119.2965, 'fuzhou fz'),
  new CityEntry('厦门', 24.4798, 118.0894, 'xiamen xm'),
  new CityEntry('南昌', 28.6820, 115.8579, 'nanchang nc'),
  new CityEntry('昆明', 25.0389, 102.7183, 'kunming km 春城'),
  new CityEntry('贵阳', 26.6470, 106.6302, 'guiyang gy'),
  new CityEntry('南宁', 22.8170, 108.3665, 'nanning nn'),
  new CityEntry('海口', 20.0444, 110.1999, 'haikou hk'),
  new CityEntry('三亚', 18.2528, 109.5119, 'sanya sy'),
  new CityEntry('兰州', 36.0611, 103.8343, 'lanzhou lz'),
  new CityEntry('西宁', 36.6171, 101.7782, 'xining xn'),
  new CityEntry('银川', 38.4872, 106.2309, 'yinchuan yc'),
  new CityEntry('乌鲁木齐', 43.8256, 87.6168, 'wulumuqi wlmq'),
  new CityEntry('拉萨', 29.6520, 91.1721, 'lasa ls 西藏'),
  new CityEntry('呼和浩特', 40.8414, 111.7519, 'huhehaote hhht'),
  new CityEntry('太原', 37.8706, 112.5489, 'taiyuan ty'),
  new CityEntry('石家庄', 38.0428, 114.5149, 'shijiazhuang sjz'),
  new CityEntry('宁波', 29.8683, 121.5440, 'ningbo nb'),
  new CityEntry('温州', 27.9938, 120.6994, 'wenzhou wz'),
  new CityEntry('无锡', 31.4912, 120.3119, 'wuxi wx'),
  new CityEntry('佛山', 23.0218, 113.1219, 'foshan fs'),
  new CityEntry('东莞', 23.0207, 113.7518, 'dongguan dg'),
  new CityEntry('珠海', 22.2707, 113.5767, 'zhuhai zh'),
  new CityEntry('桂林', 25.2736, 110.2900, 'guilin gl'),
  new CityEntry('洛阳', 34.6197, 112.4540, 'luoyang ly'),
  new CityEntry('烟台', 37.4638, 121.4479, 'yantai yt'),
  new CityEntry('威海', 37.5128, 122.1201, 'weihai wh'),
  new CityEntry('喀什', 39.4704, 75.9898, 'kashi ks'),
  new CityEntry('漠河', 52.9704, 122.5388, 'mohe mh 北极村'),
  new CityEntry('黑河', 50.2458, 127.5287, 'heihe hh'),
  new CityEntry('香港', 22.3193, 114.1694, 'hongkong hk 中国香港'),
  new CityEntry('澳门', 22.1987, 113.5439, 'macao macau 中国澳门'),
  new CityEntry('台北', 25.0330, 121.5654, 'taipei 中国台湾'),
  new CityEntry('东京', 35.6762, 139.6503, 'tokyo 日本'),
  new CityEntry('首尔', 37.5665, 126.9780, 'seoul 韩国'),
  new CityEntry('新加坡', 1.3521, 103.8198, 'singapore'),
  new CityEntry('曼谷', 13.7563, 100.5018, 'bangkok 泰国'),
  new CityEntry('悉尼', -33.8688, 151.2093, 'sydney 澳大利亚'),
  new CityEntry('伦敦', 51.5074, -0.1278, 'london 英国'),
  new CityEntry('巴黎', 48.8566, 2.3522, 'paris 法国'),
  new CityEntry('纽约', 40.7128, -74.0060, 'newyork 美国'),
  new CityEntry('洛杉矶', 34.0522, -118.2437, 'losangeles 美国'),
  new CityEntry('温哥华', 49.2827, -123.1207, 'vancouver 加拿大'),
  new CityEntry('莫斯科', 55.7558, 37.6173, 'moscow 俄罗斯'),
  new CityEntry('迪拜', 25.2048, 55.2708, 'dubai 阿联酋')
];

/**
 * 城市中文名 → 英文名（离线兜底）
 *
 * 系统地名解析会按 locale 返回对应语言，但部分地区/机型只返回中文。
 * 英文界面下如果拿到的还是中文，就用这张表换掉 —— 至少主要城市不会中英混排。
 * 表里没有的（小城市、区县）保持原样，总比显示成经纬度强。
 */
const CITY_EN: Map<string, string> = new Map<string, string>([
  ['北京', 'Beijing'], ['上海', 'Shanghai'], ['广州', 'Guangzhou'], ['深圳', 'Shenzhen'],
  ['杭州', 'Hangzhou'], ['成都', 'Chengdu'], ['重庆', 'Chongqing'], ['武汉', 'Wuhan'],
  ['西安', "Xi'an"], ['南京', 'Nanjing'], ['天津', 'Tianjin'], ['苏州', 'Suzhou'],
  ['长沙', 'Changsha'], ['郑州', 'Zhengzhou'], ['青岛', 'Qingdao'], ['沈阳', 'Shenyang'],
  ['大连', 'Dalian'], ['哈尔滨', 'Harbin'], ['长春', 'Changchun'], ['济南', 'Jinan'],
  ['合肥', 'Hefei'], ['福州', 'Fuzhou'], ['厦门', 'Xiamen'], ['南昌', 'Nanchang'],
  ['昆明', 'Kunming'], ['贵阳', 'Guiyang'], ['南宁', 'Nanning'], ['海口', 'Haikou'],
  ['三亚', 'Sanya'], ['兰州', 'Lanzhou'], ['西宁', 'Xining'], ['银川', 'Yinchuan'],
  ['乌鲁木齐', 'Urumqi'], ['拉萨', 'Lhasa'], ['呼和浩特', 'Hohhot'], ['太原', 'Taiyuan'],
  ['石家庄', 'Shijiazhuang'], ['宁波', 'Ningbo'], ['温州', 'Wenzhou'], ['无锡', 'Wuxi'],
  ['佛山', 'Foshan'], ['东莞', 'Dongguan'], ['珠海', 'Zhuhai'], ['桂林', 'Guilin'],
  ['洛阳', 'Luoyang'], ['烟台', 'Yantai'], ['威海', 'Weihai'], ['喀什', 'Kashgar'],
  ['漠河', 'Mohe'], ['黑河', 'Heihe'],
  ['香港', 'Hong Kong, China'], ['澳门', 'Macao, China'], ['台北', 'Taipei, China'],
  ['东京', 'Tokyo'], ['首尔', 'Seoul'], ['新加坡', 'Singapore'], ['曼谷', 'Bangkok'],
  ['悉尼', 'Sydney'], ['伦敦', 'London'], ['巴黎', 'Paris'], ['纽约', 'New York'],
  ['洛杉矶', 'Los Angeles'], ['温哥华', 'Vancouver'], ['莫斯科', 'Moscow'], ['迪拜', 'Dubai']
]);

/** 判断字符串里是否含中日韩字符 —— 有就说明地名没被本地化成英文 */
const CJK_RE: RegExp = new RegExp('[\\u4e00-\\u9fa5]');
/** 行政区划后缀，查英文名前先去掉：「北京市」→「北京」 */
const CITY_SUFFIX_RE: RegExp = new RegExp('[市县区旗盟]$');

export class LocationService {

  /** 动态申请定位权限，返回是否已授权 */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    // 合规闸门：用户未同意隐私政策前，一律不弹权限框、不取位置
    if (!PrivacyConsent.isAgreed()) {
      console.warn('[LocationService] 未同意隐私政策，已阻止定位权限申请');
      return false;
    }
    // 已经有权限（精确或模糊任一）就直接用，不重复弹窗
    if (await LocationService.hasPermission(context)) {
      return true;
    }
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // 先申请精确；用户只给了模糊权限时，再单独申请模糊
    if (await LocationService.requestOne(atManager, context, PRECISE_PERMISSION)) {
      return true;
    }
    return await LocationService.requestOne(atManager, context, FUZZY_PERMISSION);
  }

  /** 单独申请一个权限（同组权限不能合并申请） */
  private static async requestOne(atManager: abilityAccessCtrl.AtManager,
    context: common.UIAbilityContext, permission: Permissions): Promise<boolean> {
    try {
      const result = await atManager.requestPermissionsFromUser(context, [permission]);
      const granted: number[] = result.authResults;
      return granted.length > 0 && granted[0] === 0;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.error(`[LocationService] 申请权限失败(${permission}): ${e.code} ${e.message}`);
      return false;
    }
  }

  /** 取一次当前位置。失败返回 null（调用方可回退到已保存位置） */
  static async getCurrentLocation(context: common.UIAbilityContext): Promise<LocationResult | null> {
    const ok: boolean = await LocationService.requestPermission(context);
    if (!ok) {
      return null;
    }

    try {
      const request: geoLocationManager.CurrentLocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        timeoutMs: 10000,
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

  /**
   * 逆地理编码：坐标 → 地名。拿不到时回落成坐标文本。
   */
  static async reverseGeocode(latitude: number, longitude: number): Promise<string> {
    const name: string | null = await LocationService.reverseGeocodeRaw(latitude, longitude);
    if (name !== null) {
      return name;
    }
    return `${latitude.toFixed(2)}°, ${longitude.toFixed(2)}°`;
  }

  /**
   * 逆地理编码的原始实现：拿不到地名返回 null。
   *
   * 拆出来是因为「重刷已存地名」不能接受坐标文本 —— 那会把好好一个「北京」
   * 覆盖成「39.90°, 116.41°」，宁可保留旧值。
   */
  private static async reverseGeocodeRaw(latitude: number, longitude: number): Promise<string | null> {
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return null;
      }
      return await LocationService.reverseGeocodeAt(latitude, longitude, Locale.geocodeLocale());
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[LocationService] 逆地理编码失败: ${e.code} ${e.message}`);
      return null;
    }
  }

  private static async reverseGeocodeAt(latitude: number, longitude: number,
    localeTag: string): Promise<string | null> {
    try {
      const reverseGeocodeRequest: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: latitude,
        longitude: longitude,
        maxItems: 1,
        // 注意：这里只认纯语言码。实测传 'en-US' 系统照旧返回「东营市」，
        // 传 'en' 才返回 'Dongying'（'zh-CN' 反而正常，所以只有英文侧会踩这个坑）。
        locale: localeTag
      };
      const addresses: Array<geoLocationManager.GeoAddress> =
        await geoLocationManager.getAddressesFromLocation(reverseGeocodeRequest);
      if (addresses.length === 0) {
        return null;
      }
      const addr: geoLocationManager.GeoAddress = addresses[0];
      // 优先取城市，其次区县，最后街道
      let name: string = '';
      if (addr.locality && addr.locality.length > 0) {
        name = addr.locality;
      } else if (addr.subLocality && addr.subLocality.length > 0) {
        name = addr.subLocality;
      } else if (addr.placeName && addr.placeName.length > 0) {
        name = addr.placeName;
      }
      if (name.length === 0) {
        return null;
      }
      return Locale.isZh() ? name : LocationService.toEnglishName(name);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      console.warn(`[LocationService] 逆地理编码失败: ${e.code} ${e.message}`);
      return null;
    }
  }

  /**
   * 英文界面下的地名兜底。
   *
   * 系统地名服务不一定真的按 locale 返回英文（部分机型/地区仍返回中文），
   * 这里再兜一层：已经是英文就直接用；还是中文就去后缀查 CITY_EN，查不到保持原样。
   */
  private static toEnglishName(name: string): string {
    if (!CJK_RE.test(name)) {
      return name;
    }
    const stripped: string = name.replace(CITY_SUFFIX_RE, '');
    const hit: string | undefined = CITY_EN.get(stripped);
    return hit !== undefined ? hit : name;
  }

  /**
   * 已存地名和当前界面语言是否对不上（英文界面挂着中文名，或反之）。
   *
   * 先用它挡一道，绝大多数情况（语言没变过）连系统调用都不用发。
   */
  private static nameMismatch(name: string): boolean {
    if (name.length === 0) {
      return false;
    }
    const cjk: boolean = CJK_RE.test(name);
    return Locale.isZh() ? !cjk : cjk;
  }

  /**
   * 切换语言后重刷已存地名。
   *
   * 地名是「定位那一刻按当时的语言」解析好写进 Preferences 的，切语言它不会自己变，
   * 不重刷的话英文界面会一直挂着「北京」。拿不到新地名时保留旧值，绝不写回坐标文本。
   *
   * @returns 是否有名字真的变了（变了调用方要刷新界面）
   */
  static async localizeStoredNames(): Promise<boolean> {
    let changed: boolean = false;

    // ---- 1) 当前位置 ----
    const lat: number = SettingsStore.getLatitude();
    const lng: number = SettingsStore.getLongitude();
    if ((lat !== 0 || lng !== 0) && LocationService.nameMismatch(SettingsStore.getLocationName())) {
      const fresh: string | null = await LocationService.reverseGeocodeRaw(lat, lng);
      if (fresh !== null && fresh !== SettingsStore.getLocationName()) {
        try {
          await SettingsStore.saveLocation(lat, lng, fresh, SettingsStore.isAutoLocate());
          changed = true;
        } catch (err) {
          const e: BusinessError = err as BusinessError;
          console.warn(`[LocationService] 重刷当前位置名失败: ${e.code} ${e.message}`);
        }
      }
    }

    // ---- 2) 已保存地点 ----
    const saved: SavedLocation[] = SettingsStore.getSavedLocations();
    if (saved.length > 0) {
      const next: SavedLocation[] = [];
      let renamed: boolean = false;
      for (const it of saved) {
        let name: string = it.name;
        if (LocationService.nameMismatch(it.name)) {
          const fresh: string | null =
            await LocationService.reverseGeocodeRaw(it.latitude, it.longitude);
          if (fresh !== null && fresh !== it.name) {
            name = fresh;
            renamed = true;
          }
        }
        next.push(new SavedLocation(name, it.latitude, it.longitude, it.isAuto));
      }
      if (renamed) {
        try {
          await SettingsStore.replaceSavedLocations(next);
          changed = true;
        } catch (err) {
          const e: BusinessError = err as BusinessError;
          console.warn(`[LocationService] 重刷已保存地点名失败: ${e.code} ${e.message}`);
        }
      }
    }

    return changed;
  }

  /**
   * 按名称搜索地点（对齐 Android LocationService.searchCities）
   *
   * 先查内置城市表（支持中文、拼音、别名），结果不足 5 条时再调系统地名解析兜底。
   * 每项返回可直接使用的经纬度。
   */
  static async searchCities(query: string): Promise<LocationResult[]> {
    const q: string = query.trim();
    if (q.length === 0) {
      return [];
    }
    const qLower: string = q.toLowerCase();
    const out: LocationResult[] = [];
    const seen: string[] = [];

    const pushUnique = (name: string, lat: number, lng: number): void => {
      const key: string = `${lat.toFixed(2)},${lng.toFixed(2)}`;
      if (seen.indexOf(key) >= 0) {
        return;
      }
      seen.push(key);
      out.push(new LocationResult(lat, lng, name));
    };

    // 1) 内置城市表
    for (const c of CITY_TABLE) {
      if (c.name.indexOf(q) >= 0 || c.keys.indexOf(qLower) >= 0) {
        // 英文界面下结果也显示英文，否则搜出来一排中文
        const display: string = Locale.isZh() ? c.name : LocationService.toEnglishName(c.name);
        pushUnique(display, c.lat, c.lng);
      }
    }

    // 2) 系统地名解析兜底
    if (out.length < 5) {
      try {
        if (geoLocationManager.isGeocoderAvailable()) {
          const req: geoLocationManager.GeoCodeRequest = {
            description: q,
            maxItems: 5,
            locale: Locale.geocodeLocale()
          };
          const addrs: Array<geoLocationManager.GeoAddress> =
            await geoLocationManager.getAddressesFromLocationName(req);
          for (const a of addrs) {
            const raw: string = (a.locality && a.locality.length > 0) ? a.locality
              : ((a.placeName && a.placeName.length > 0) ? a.placeName : q);
            const name: string = Locale.isZh() ? raw : LocationService.toEnglishName(raw);
            const lat: number = Number(a.latitude ?? 0);
            const lng: number = Number(a.longitude ?? 0);
            if (lat === 0 && lng === 0) {
              continue;
            }
            pushUnique(name, lat, lng);
          }
        }
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        console.warn(`[LocationService] 地名搜索失败: ${e.code} ${e.message}`);
      }
    }

    return out.slice(0, 5);
  }

  /** 检查是否已有定位权限（不弹窗）。精确或模糊任一授予即算可用 */
  static async hasPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = context.applicationInfo.accessTokenId;
      const precise: abilityAccessCtrl.GrantStatus =
        await atManager.checkAccessToken(tokenId, PRECISE_PERMISSION);
      if (precise === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      const fuzzy: abilityAccessCtrl.GrantStatus =
        await atManager.checkAccessToken(tokenId, FUZZY_PERMISSION);
      return fuzzy === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      return false;
    }
  }
}
